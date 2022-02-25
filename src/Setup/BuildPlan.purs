module Setup.BuildPlan (constructBuildPlan, BuildPlan) where

import Prelude

import Control.Monad.Except.Trans (ExceptT, mapExceptT)
import Data.Argonaut.Core (Json)
import Data.Argonaut.Decode (decodeJson, printJsonDecodeError, (.:))
import Data.Array as Array
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Foldable (fold)
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..))
import Data.String as String
import Data.Traversable (traverse)
import Data.Version (Version)
import Data.Version as Version
import Effect.Aff (Aff, error, throwError)
import Effect.Aff.Class (liftAff)
import Effect.Class (liftEffect)
import Effect.Exception (Error)
import GitHub.Actions.Core as Core
import Setup.Data.Key (Key)
import Setup.Data.Key as Key
import Setup.Data.Tool (Tool)
import Setup.Data.Tool as Tool
import Setup.UpdateVersions (ReleaseType(..), fetchFromGitHubReleases)
import Text.Parsing.Parser (parseErrorMessage)
import Text.Parsing.Parser as ParseError

-- | The list of tools that should be downloaded and cached by the action
type BuildPlan = Array { tool :: Tool, version :: Version }

-- | Construct the list of tools that sholud be downloaded and cached by the action
constructBuildPlan :: Json -> ExceptT Error Aff BuildPlan
constructBuildPlan json = map Array.catMaybes $ traverse (resolve json) Tool.allTools

-- | The parsed value of an input field that specifies a version
data VersionField
  -- | Pre-releases for versions matching the given version
  = Unstable Version
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
    val
      | Just versionStr <- String.stripPrefix (Pattern "unstable-") val -> do
          if Key.toString key /= "purescript" then do
            liftEffect $ Core.error $
              fold [ "Pre-release versions only work for the PureScript tool" ]
            throwError (error $ fold [ "Could not get version for key ", Key.toString key ])
          else case Version.parseVersion versionStr of
            Left msg -> do
              liftEffect $ Core.error $
                fold [ "Failed to parse pre-release version ", versionStr ]
              throwError (error (ParseError.parseErrorMessage msg))
            Right v -> do
              pure (pure (Unstable v))

      | otherwise -> case Version.parseVersion val of
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
      Core.info $ fold [ "Fetching latest tag for ", Tool.name tool ]

      let
        version = lmap printJsonDecodeError $ (_ .: Tool.name tool) =<< decodeJson versionsContents
        parse = lmap parseErrorMessage <<< Version.parseVersion

      case parse =<< version of
        Left e -> do
          Core.setFailed $ fold [ "Unable to parse version: ", e ]
          throwError $ error "Unable to complete fetching version."

        Right v -> do
          pure (pure { tool, version: v })

    Just (Unstable v) -> do
      liftEffect do
        Core.info $ fold [ "Fetching most recent pre-release for ", Tool.name tool, "@", Version.showVersion v ]
      version <- liftAff $ fetchFromGitHubReleases (OnlyPreReleases v) (Tool.repository tool)
      pure (pure { tool, version })
