module Setup.DownloadTool 
  ( downloadTool 
  ) where

import Prelude

import Actions.Core as Core
import Actions.ToolCache as ToolCache
import Affjax as AX
import Affjax.ResponseFormat as RF
import Data.Argonaut.Decode (decodeJson, printJsonDecodeError, (.:))
import Data.Array (catMaybes, reverse, sort)
import Data.Array as Array
import Data.Either (Either(..), hush)
import Data.Foldable (fold)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Newtype (unwrap)
import Data.String as String
import Data.Time.Duration (class Duration, fromDuration)
import Data.Traversable (traverse)
import Data.Version (Version)
import Data.Version as Version
import Effect.Aff (Aff, Error, Milliseconds(..), error, throwError)
import Effect.Aff.Retry (RetryPolicy, RetryPolicyM, RetryStatus(..), limitRetries, recovering, retryPolicy)
import Effect.Class (liftEffect)
import Math (pow)
import Node.Path (FilePath)
import Node.Path as Path
import Setup.Data.Input (Input(..), VersionField(..))
import Setup.Data.Input as Input
import Setup.Data.Platform (Platform(..), platform)
import Setup.Data.Tool (Tool(..), tarballSource)
import Setup.Data.Tool as Tool
import Text.Parsing.Parser (parseErrorMessage)

downloadTool :: Tool -> Aff Unit
downloadTool tool = do
  version <- resolveVersion tool
  let name = Tool.name tool
  
  liftEffect (ToolCache.find tool version) >>= case _ of
    Just path -> liftEffect do
      Core.info $ fold 
        [ "Found cached version of "
        , unwrap name
        , " at version "
        , Version.showVersion version
        , " at path "
        , path
        , ", adding to PATH." 
        ]
      
      Core.addPath path
    
    Nothing -> do
      liftEffect $ Core.info $ fold 
        [ "Did not find cached version of "
        , unwrap name
        , " at version "
        , Version.showVersion version
        , ", downloading..." 
        ]
      
      executable <- downloadResolved tool version
      cached <- ToolCache.cacheFile { source: executable, tool, version }
      
      liftEffect do
        Core.info $ fold [ "Cached path ", cached, ", adding to PATH" ]
        Core.addPath cached

downloadResolved :: Tool -> Version -> Aff FilePath
downloadResolved tool version = do
  let source = tarballSource tool version
  liftEffect $ Core.info source
  downloadPath <- ToolCache.downloadTool' source
  extractedPath <- ToolCache.extractTar' downloadPath

  -- Construct the path to the executable itself
  let 
    executable = let name = unwrap (Tool.name tool) in case platform of
      Windows -> name <> ".exe"
      _ -> name
          
  pure $ Path.concat $ case tool of
    PureScript -> [ extractedPath, "purescript", executable ]
    Zephyr -> [ extractedPath, "zephyr", executable ]
    Purty -> [ extractedPath, executable ]
    Spago -> [ extractedPath, executable ]

-- | Resolve the exact version to provide for a tool in the environment, based
-- | on the action.yml file.
resolveVersion :: Tool -> Aff Version
resolveVersion tool = do
  let toolInput = Version tool
  input <- liftEffect $ map Input.parseVersionField $ Core.getInput toolInput

  case input of
    Left err -> do
      liftEffect $ Core.setFailed $ fold 
        [ "Input not valid for key: "
        , Input.toKey toolInput
        , "\n\nFailed with error:\n\n  "
        , err
        ]
      throwError $ error "Unable to complete fetching version."
    
    Right (Exact v) -> do
      liftEffect $ Core.info "Found exact version"
      pure v

    Right Latest -> do
      liftEffect $ Core.info $ fold [ "Fetching latest tag for ", unwrap (Tool.name tool) ]
      fetchLatestReleaseVersion tool

-- | Find the latest release version for a given tool. Prefers explicit releases
-- | as listed in GitHub releases, but for tools which don't support GitHub
-- | releases, falls back to the highest valid semantic version tag for the tool.
fetchLatestReleaseVersion :: Tool -> Aff Version
fetchLatestReleaseVersion tool = Tool.repository tool # case tool of
  PureScript -> fetchFromGitHubReleases
  Spago -> fetchFromGitHubReleases
  -- Technically, Purty is hosted on Gitlab. But without an accessible way to
  -- fetch the latest release tag from Gitlab via an API, it seems better to fetch
  -- from the GitHub mirror.
  Purty -> fetchFromGitHubTags
  Zephyr -> fetchFromGitHubReleases
  where
  -- TODO: These functions really ought to be in ExceptT to avoid all the 
  -- nested branches.
  fetchFromGitHubReleases repo = recover do
    let url = "https://api.github.com/repos/" <> repo.owner <> "/" <> repo.name <> "/releases/latest"

    AX.get RF.json url >>= case _ of
      Left err -> do
        throwError (error $ AX.printError err)
      
      Right { body } -> case (_ .: "tag_name") =<< decodeJson body of
        Left e -> do
          throwError $ error $ fold [ "Failed to decode GitHub response: ", printJsonDecodeError e ]

        Right tagStr -> do
          let tag = fromMaybe tagStr (String.stripPrefix (String.Pattern "v") tagStr)
          case Version.parseVersion tag of
            Left e -> do
              throwError $ error $ fold 
                [ "Failed to decode tag from GitHub response: "
                , parseErrorMessage e 
                ]

            Right v ->
              pure v

  -- If a tool doesn't use GitHub releases and instead only tags versions, then
  -- we have to fetch the tags, parse them as appropriate versions, and then sort
  -- them according to their semantic version to get the latest one.
  fetchFromGitHubTags repo = recover do
    let url = "https://api.github.com/repos/" <> repo.owner <> "/" <> repo.name <> "/tags"

    AX.get RF.json url >>= case _ of
      Left err -> do
        throwError (error $ AX.printError err)
      
      Right { body } -> case traverse (_ .: "name") =<< decodeJson body of
        Left e -> do
          throwError $ error "Could not download repository tags."

        Right arr -> do
          let 
            tags = catMaybes $ map (\t -> hush $ Version.parseVersion $ fromMaybe t $ String.stripPrefix (String.Pattern "v") t) arr
            sorted = reverse $ sort tags

          case Array.head sorted of
            Nothing ->
              throwError $ error "Could not download latest release version."

            Just v ->
              pure v

-- Attempt to recover from a failed request by re-attempting according to an
-- exponential backoff strategy.
recover :: Aff ~> Aff
recover action = recovering policy checks \_ -> action
  where
  policy :: RetryPolicyM Aff
  policy = exponentialBackoff (Milliseconds 5000.0) <> limitRetries 3

  checks :: Array (RetryStatus -> Error -> Aff Boolean)
  checks = pure (\_ -> \_ -> pure true)

  exponentialBackoff :: forall d. Duration d => d -> RetryPolicy
  exponentialBackoff base = 
    retryPolicy \(RetryStatus { iterNumber: n }) ->
      Just $ Milliseconds $ unwrap (fromDuration base) * pow 3.0 (toNumber n)
