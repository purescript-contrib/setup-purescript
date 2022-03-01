module Setup.BuildPlan (constructBuildPlan, BuildPlan) where

import Prelude

import Control.Monad.Except.Trans (ExceptT, mapExceptT)
import Data.Argonaut.Core (Json, stringify)
import Data.Argonaut.Decode (decodeJson, printJsonDecodeError)
import Data.Array as Array
import Data.Bifunctor (lmap)
import Data.Either (Either(..), note)
import Data.Foldable (fold)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Data.Version (Version)
import Data.Version as Version
import Effect.Aff (Aff, error, throwError)
import Effect.Class (liftEffect)
import Effect.Exception (Error)
import GitHub.Actions.Core as Core
import Setup.Data.Key (Key)
import Setup.Data.Key as Key
import Setup.Data.Tool (Tool, ToolMap(..))
import Setup.Data.Tool as Tool
import Text.Parsing.Parser (parseErrorMessage)
import Text.Parsing.Parser as ParseError

-- | The list of tools that should be downloaded and cached by the action
type BuildPlan = Array { tool :: Tool, version :: Version }

-- | Construct the list of tools that sholud be downloaded and cached by the action
constructBuildPlan :: Json -> ExceptT Error Aff BuildPlan
constructBuildPlan json = map Array.catMaybes $ traverse (resolve json) Tool.allTools

-- | The parsed value of an input field that specifies a version
data VersionField
  -- | Lookup the latest release, pre-release or not
  = Unstable
  -- | Lookup the latest release that is not a pre-release
  | Latest
  -- | Use the given version
  | Exact Version

-- | Attempt to read the value of an input specifying a tool version
getVersionField :: Key -> ExceptT Error Aff (Maybe VersionField)
getVersionField key = do
  value <- mapExceptT liftEffect $ Core.getInput' (Key.toString key)
  case value of
    "" ->
      pure Nothing
    "latest" ->
      pure (pure Latest)
    "unstable" ->
      pure (pure Unstable)
    val -> case Version.parseVersion val of
      Left msg -> do
        liftEffect $ Core.error $ fold [ "Failed to parse version ", val ]
        throwError (error (ParseError.parseErrorMessage msg))
      Right version ->
        pure (pure (Exact version))

-- | Resolve the exact version to provide for a tool in the environment, based
-- | on the action.yml file.
resolve :: Json -> Tool -> ExceptT Error Aff (Maybe { tool :: Tool, version :: Version })
resolve versionsContents tool = do
  let key = Key.fromTool tool
  field <- getVersionField key
  case field of
    Nothing -> pure Nothing

    Just (Exact v) -> liftEffect do
      Core.info "Found exact version"
      pure (pure { tool, version: v })

    Just Latest -> liftEffect do
      Core.info $ fold [ "Fetching latest stable tag for ", Tool.name tool ]
      readVersionFromFile "latest" _.latest

    Just Unstable -> liftEffect do
      Core.info $ fold [ "Fetching latest tag (pre-release or not) for ", Tool.name tool ]
      readVersionFromFile "unstable" _.unstable
  where
  readVersionFromFile fieldName fieldSelector = do
    let
      decodeVersion = do
        ToolMap toolMap <- lmap printJsonDecodeError $ decodeJson versionsContents
        rec <- note (fold [ "Tool \"", Tool.name tool, "\" not found." ]) $ Map.lookup tool toolMap
        lmap parseErrorMessage $ Version.parseVersion $ fieldSelector rec

    case decodeVersion of
      Left e -> do
        Core.setFailed $ fold [ "Unable to parse version for field '", fieldName, "': ", e ]
        throwError $ error "Unable to complete fetching version."

      Right v -> do
        pure (pure { tool, version: v })
