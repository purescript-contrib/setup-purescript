-- | The source used to fetch and update the latest versions in the versions.json
-- | file, which records the latest version of each tool.
module Setup.UpdateVersions (updateVersions) where

import Prelude

import Affjax as AX
import Affjax.ResponseFormat as RF
import Control.Monad.Rec.Class (untilJust)
import Data.Argonaut.Core (Json, jsonEmptyObject, stringify)
import Data.Argonaut.Decode (decodeJson, printJsonDecodeError, (.:))
import Data.Argonaut.Encode ((:=), (~>))
import Data.Array (foldl)
import Data.Array as Array
import Data.Either (Either(..), hush)
import Data.Foldable (fold)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe, isNothing)
import Data.String as String
import Data.Traversable (for, traverse)
import Data.Tuple (Tuple(..))
import Data.Version (Version)
import Data.Version as Version
import Effect (Effect)
import Effect.Aff (Aff, Error, Milliseconds(..), delay, error, throwError)
import Effect.Aff.Retry (RetryPolicy, RetryPolicyM, RetryStatus(..))
import Effect.Aff.Retry as Retry
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import GitHub.Actions.Core (warning)
import Math (pow)
import Node.Encoding (Encoding(..))
import Node.FS.Sync (writeTextFile)
import Node.Path (FilePath)
import Setup.Data.Tool (Tool(..))
import Setup.Data.Tool as Tool

-- | Write the latest version of each supported tool
updateVersions :: Aff Unit
updateVersions = do
  versions <- for Tool.allTools \tool -> do
    delay (Milliseconds 500.0)
    version <- fetchLatestReleaseVersion tool
    pure $ Tuple tool version

  let
    insert obj (Tuple tool version) =
      Tool.name tool := Version.showVersion version ~> obj

  liftEffect $ writeVersionsFile $ foldl insert jsonEmptyObject versions
  where
  versionsFilePath :: FilePath
  versionsFilePath = "./dist/versions.json"

  writeVersionsFile :: Json -> Effect Unit
  writeVersionsFile = writeTextFile UTF8 versionsFilePath <<< stringify

-- | Find the latest release version for a given tool. Prefers explicit releases
-- | as listed in GitHub releases, but for tools which don't support GitHub
-- | releases, falls back to the highest valid semantic version tag for the tool.
fetchLatestReleaseVersion :: Tool -> Aff Version
fetchLatestReleaseVersion tool = Tool.repository tool # case tool of
  PureScript -> fetchFromGitHubReleases
  Spago -> fetchFromGitHubReleases
  Psa -> fetchFromGitHubTags
  -- Technically, Purty is hosted on Gitlab. But without an accessible way to
  -- fetch the latest release tag from Gitlab via an API, it seems better to fetch
  -- from the GitHub mirror.
  Purty -> fetchFromGitHubTags
  Zephyr -> fetchFromGitHubReleases
  where
  -- TODO: These functions really ought to be in ExceptT to avoid all the
  -- nested branches.
  fetchFromGitHubReleases repo = recover do
    page <- liftEffect (Ref.new 1)
    untilJust do
      versions <- liftEffect (Ref.read page) >>= toolVersions repo
      case versions of
        Just versions' -> do
          let version = Array.find (not <<< Version.isPreRelease) versions'
          when (isNothing version) do
            liftEffect $ void $ Ref.modify (_ + 1) page
          pure version

        Nothing ->
          throwError $ error "Could not find version that is not a pre-release version"

  toolVersions :: Tool.ToolRepository -> Int -> Aff (Maybe (Array Version))
  toolVersions repo page = do
    let
      url = "https://api.github.com/repos/" <> repo.owner <> "/" <> repo.name <> "/releases?per_page=10&page=" <> show page
    AX.get RF.json url
      >>= case _ of
          Left err -> throwError (error $ AX.printError err)
          Right { body } -> case decodeJson body of
            Left e -> do
              throwError $ error
                $ fold
                    [ "Failed to decode GitHub response. This is most likely due to a timeout.\n\n"
                    , printJsonDecodeError e
                    , stringify body
                    ]
            Right [] -> pure Nothing
            Right objects ->
              Just
                <$> Array.catMaybes
                <$> for objects \obj ->
                  case obj .: "tag_name" of
                    Left e ->
                      throwError $ error $ fold
                        [ "Failed to get tag from GitHub response: "
                        , printJsonDecodeError e
                        ]
                    Right tagName ->
                      case tagStrToVersion tagName of
                        Left e -> do
                          liftEffect $ warning $ fold
                            [ "Got invalid version"
                            , tagName
                            , " from "
                            , repo.name
                            ]
                          pure Nothing
                        Right version -> case obj .: "draft" of
                          Left e ->
                            throwError $ error $ fold
                              [ "Failed to get draft from GitHub response: "
                              , printJsonDecodeError e
                              ]
                          Right isDraft ->
                            if isDraft
                              then pure Nothing
                              else pure (Just version)

  tagStrToVersion tagStr =
    tagStr
      # String.stripPrefix (String.Pattern "v")
      # fromMaybe tagStr
      # Version.parseVersion

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
          throwError $ error $ fold
            [ "Failed to decode GitHub response. This is most likely due to a timeout.\n\n"
            , printJsonDecodeError e
            , stringify body
            ]

        Right arr -> do
          let
            tags = Array.catMaybes $ map (tagStrToVersion >>> hush) arr
            sorted = Array.reverse $ Array.sort tags

          case Array.head sorted of
            Nothing ->
              throwError $ error "Could not download latest release version."

            Just v ->
              pure v

-- Attempt to recover from a failed request by re-attempting according to an
-- exponential backoff strategy.
recover :: Aff ~> Aff
recover action = Retry.recovering policy checks \_ -> action
  where
  policy :: RetryPolicyM Aff
  policy = exponentialBackoff (Milliseconds 5000.0) <> Retry.limitRetries 4

  checks :: Array (RetryStatus -> Error -> Aff Boolean)
  checks = [ \_ -> \_ -> pure true ]

  exponentialBackoff :: Milliseconds -> RetryPolicy
  exponentialBackoff (Milliseconds base) =
    Retry.retryPolicy
      \(RetryStatus { iterNumber: n }) ->
        Just $ Milliseconds $ base * pow 3.0 (toNumber n)
