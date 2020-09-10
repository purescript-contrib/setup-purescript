module Setup.BuildPlan (constructBuildPlan, BuildPlan) where

import Prelude

import Control.Monad.Except.Trans (ExceptT)
import Data.Argonaut.Core (Json)
import Data.Argonaut.Decode (decodeJson, printJsonDecodeError, (.:))
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Foldable (fold)
import Data.Newtype (unwrap)
import Data.Traversable (traverse)
import Data.Version (Version)
import Data.Version as Version
import Effect (Effect)
import Effect.Aff (error, throwError)
import Effect.Class (liftEffect)
import Effect.Exception (Error)
import GitHub.Actions.Core as Core
import Setup.Data.Key (Key)
import Setup.Data.Key as Key
import Setup.Data.Tool (Tool)
import Setup.Data.Tool as Tool
import Text.Parsing.Parser (parseErrorMessage)
import Text.Parsing.Parser as ParseError

-- | The list of tools that should be downloaded and cached by the action
type BuildPlan = Array { tool :: Tool, version :: Version }

-- | Construct the list of tools that sholud be downloaded and cached by the action
constructBuildPlan :: Json -> ExceptT Error Effect BuildPlan
constructBuildPlan json = traverse (resolve json) Tool.allTools

-- | The parsed value of an input field that specifies a version
data VersionField = Latest | Exact Version

-- | Attempt to read the value of an input specifying a tool version
getVersionField :: Key -> ExceptT Error Effect VersionField
getVersionField key = do
  value <- Core.getInput' (unwrap key)
  case value of
    "latest" -> pure Latest
    val -> case Version.parseVersion val of
      Left msg -> throwError (error (ParseError.parseErrorMessage msg))
      Right version -> pure (Exact version)

-- | Resolve the exact version to provide for a tool in the environment, based
-- | on the action.yml file.
resolve :: Json -> Tool -> ExceptT Error Effect { tool :: Tool, version :: Version }
resolve versionsContents tool = do
  let key = Key.fromTool tool
  field <- getVersionField key
  case field of
    Exact v -> liftEffect do
      Core.info "Found exact version"
      pure { tool, version: v }

    Latest -> liftEffect do
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
