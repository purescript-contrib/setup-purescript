module Setup.BuildPlan (constructBuildPlan, BuildPlan) where

import Prelude

import Actions.Core as Core
import Data.Argonaut.Core (Json)
import Data.Argonaut.Decode (decodeJson, printJsonDecodeError, (.:))
import Data.Array as Array
import Data.Bifunctor (bimap, lmap)
import Data.Either (Either(..))
import Data.Foldable (fold)
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Data.Version (Version)
import Data.Version as Version
import Effect (Effect)
import Effect.Aff (error, throwError)
import Setup.Data.Key (Key)
import Setup.Data.Key as Key
import Setup.Data.Tool (Tool, required)
import Setup.Data.Tool as Tool
import Text.Parsing.Parser (parseErrorMessage)
import Text.Parsing.Parser as ParseError

-- | The list of tools that should be downloaded and cached by the action
type BuildPlan = Array { tool :: Tool, version :: Version }

-- | Construct the list of tools that sholud be downloaded and cached by the action
constructBuildPlan :: Json -> Effect BuildPlan
constructBuildPlan json = map Array.catMaybes $ traverse (resolve json) Tool.allTools

-- | The parsed value of an input field that specifies a version
data VersionField = Latest | Exact Version

-- | Attempt to read the value of an input specifying a tool version
getVersionField :: Key -> Effect (Maybe (Either String VersionField))
getVersionField = map (map parse) <<< Core.getInput
  where
  parse = case _ of
    "latest" -> pure Latest
    value -> bimap ParseError.parseErrorMessage Exact (Version.parseVersion value)

-- | Resolve the exact version to provide for a tool in the environment, based
-- | on the action.yml file.
resolve :: Json -> Tool -> Effect (Maybe { tool :: Tool, version :: Version })
resolve versionsContents tool = do
  let key = Key.fromTool tool
  getVersionField key >>= case _ of
    Nothing | required tool -> throwError $ error "No input received for required key."
    Nothing -> pure Nothing
    Just field -> map Just $ getVersion field

  where
  getVersion :: Either String VersionField -> Effect { tool :: Tool, version :: Version }
  getVersion = case _ of
    Left err -> do
      Core.setFailed $ fold [ "Unable to parse version: ", err ]
      throwError $ error "Unable to complete fetching version."

    Right (Exact v) -> do
      Core.info "Found exact version"
      pure { tool, version: v }

    Right Latest -> do
      Core.info $ fold [ "Fetching latest tag for ", Tool.name tool ]

      let
        version = lmap printJsonDecodeError $ (_ .: Tool.name tool) =<< decodeJson versionsContents
        parse = lmap parseErrorMessage <<< Version.parseVersion

      case parse =<< version of
        Left e -> do
          Core.setFailed $ fold [ "Unable to parse version: ", e ]
          throwError $ error "Unable to complete fetching version."

        Right v ->
          pure { tool, version: v }
