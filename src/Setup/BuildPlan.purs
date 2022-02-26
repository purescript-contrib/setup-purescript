module Setup.BuildPlan (constructBuildPlan, BuildPlan) where

import Prelude

import Control.Monad.Except.Trans (ExceptT)
import Data.Argonaut.Core (Json)
import Data.Argonaut.Decode (decodeJson, printJsonDecodeError, (.:))
import Data.Array as Array
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Foldable (elem, fold)
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Data.Version as Version
import Effect (Effect)
import Effect.Aff (error, throwError)
import Effect.Class (liftEffect)
import Effect.Exception (Error)
import GitHub.Actions.Core as Core
import Setup.Data.Key (Key)
import Setup.Data.Key as Key
import Setup.Data.Tool (Tool(..))
import Setup.Data.Tool as Tool
import Setup.Data.VersionField (VersionField(..))
import Text.Parsing.Parser (parseErrorMessage)
import Text.Parsing.Parser as ParseError

-- | The list of tools that should be downloaded and cached by the action
type BuildPlan = Array { tool :: Tool, versionField :: VersionField }

-- | Construct the list of tools that sholud be downloaded and cached by the action
constructBuildPlan :: Json -> ExceptT Error Effect BuildPlan
constructBuildPlan json = map Array.catMaybes $ traverse (resolve json) Tool.allTools

-- | Attempt to read the value of an input specifying a tool version
getVersionField :: Key -> ExceptT Error Effect (Maybe VersionField)
getVersionField key = do
  value <- Core.getInput' (Key.toString key)
  case value of
    "" ->
      pure Nothing
    "latest" ->
      pure (pure Latest)
    val -> case Version.parseVersion val of
      Left msg -> do
        liftEffect $ Core.error $ fold [ "Failed to parse version ", val ]
        throwError (error (ParseError.parseErrorMessage msg))
      Right version ->
        pure (pure (Exact version))

-- | Resolve the exact version to provide for a tool in the environment, based
-- | on the action.yml file. In the case of NPM packages, bypass the action.yml
-- | file and use 'Latest'.
resolve :: Json -> Tool -> ExceptT Error Effect (Maybe { tool :: Tool, versionField :: VersionField })
resolve versionsContents tool = do
  let key = Key.fromTool tool
  field <- getVersionField key
  case field, tool `elem` [ Psa, PursTidy ] of
    Nothing, _ -> pure Nothing

    Just (Exact v), _ -> liftEffect do
      Core.info "Found exact version"
      pure (pure { tool, versionField: Exact v })

    Just Latest, true -> liftEffect do
      Core.info $ fold [ "Fetching latest tag for ", Tool.name tool ]
      pure (pure { tool, versionField: Latest })

    Just Latest, false -> liftEffect do
      Core.info $ fold [ "Fetching latest tag for ", Tool.name tool ]

      let
        version = lmap printJsonDecodeError $ (_ .: Tool.name tool) =<< decodeJson versionsContents
        parse = lmap parseErrorMessage <<< Version.parseVersion

      case parse =<< version of
        Left e -> do
          Core.setFailed $ fold [ "Unable to parse version: ", e ]
          throwError $ error "Unable to complete fetching version."

        Right v -> do
          pure (pure { tool, versionField: Exact v })
