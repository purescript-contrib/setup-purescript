-- | The source used to fetch and update the latest versions in the versions.json
-- | file, which records the latest version of each tool.
module Setup.UpdateVersions (updateVersions) where

import Prelude

import Affjax.Node as Affjax.Node
import Affjax.ResponseFormat as Affjax.ResponseFormat
import Control.Alt ((<|>))
import Control.Monad.Rec.Class (class MonadRec, Step(..), tailRecM)
import Data.Argonaut.Core (Json, stringifyWithIndent)
import Data.Argonaut.Decode (decodeJson, printJsonDecodeError, (.:))
import Data.Array as Array
import Data.Either (Either(..), hush)
import Data.Foldable (fold, maximum)
import Data.Int (toNumber)
import Data.List as List
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
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
import Data.Number (pow)
import Node.Encoding (Encoding(..))
import Node.FS.Sync (writeTextFile)
import Node.Path (FilePath)
import Setup.Data.Tool (Tool(..))
import Setup.Data.Tool as Tool
import Setup.Data.VersionFiles (V1FileSchema(..), V2FileSchema(..), version1, version2)
import Parsing (ParseError)

-- | Write the latest version of each supported tool
updateVersions :: Aff Unit
updateVersions = do
  versions <- for Tool.allTools \tool -> do
    delay (Milliseconds 500.0)
    versionRec <- fetchLatestReleaseVersion tool
    pure $ Tuple tool versionRec

  updateV1File versions
  updateV2File versions
  where
  updateV1File versions = liftEffect do
    let V1FileSchema { localFile, encode } = version1
    writeVersionsFile localFile
      $ encode
      $ Map.fromFoldable
      $ map (map _.latest) versions

  updateV2File versions = liftEffect do
    let V2FileSchema { localFile, encode } = version2
    writeVersionsFile localFile
      $ encode
      $ Map.fromFoldable versions

  writeVersionsFile :: FilePath -> Json -> Effect Unit
  writeVersionsFile path = writeTextFile UTF8 path <<< (_ <> "\n") <<< stringifyWithIndent 2

-- | Find the latest release version for a given tool. Prefers explicit releases
-- | as listed in GitHub releases, but for tools which don't support GitHub
-- | releases, falls back to the highest valid semantic version tag for the tool.
fetchLatestReleaseVersion :: Tool -> Aff { latest :: Version, unstable :: Version }
fetchLatestReleaseVersion tool = case tool of
  PureScript -> fetchFromGitHubReleases toolRepository
  Spago -> fetchFromNpmReleases toolRepository.name
  Psa -> fetchFromGitHubTags toolRepository
  PursTidy -> fetchFromGitHubTags toolRepository
  Zephyr -> fetchFromGitHubReleases toolRepository
  where
  toolRepository = Tool.repository tool

type NpmOutput = { "dist-tags" :: { latest :: String, next :: String } }

-- See all versions - https://www.npmjs.com/package/spago?activeTab=versions
fetchFromNpmReleases :: String -> Aff { latest :: Version, unstable :: Version }
fetchFromNpmReleases packageName = recover do
  let url = "https://registry.npmjs.org/" <> packageName
  Affjax.Node.get Affjax.ResponseFormat.json url >>= case _ of
    Left err -> throwError (error $ Affjax.Node.printError err)
    Right { body } -> case decodeJson body of
      Left e -> do
        throwError $ error
          $ fold
              [ "Failed to decode Npm response. This is most likely due to a timeout.\n\n"
              , printJsonDecodeError e
              , stringifyWithIndent 2 body
              ]
      Right (npmOutput :: NpmOutput) -> do
        unstable <- strToVersionOrError npmOutput."dist-tags".next -- for example 0.93.x
        latest <- strToVersionOrError npmOutput."dist-tags".latest -- for example 0.21.0
        pure { latest, unstable }

  where
  strToVersionOrError :: String -> Aff Version
  strToVersionOrError tagName =
    case tagStrToVersion tagName of
      Left _ ->
        throwError $ error $ fold
          [ "Got invalid version"
          , tagName
          , " from "
          , packageName
          ]
      Right version -> pure version

-- TODO: These functions really ought to be in ExceptT to avoid all the
-- nested branches.
fetchFromGitHubReleases :: Tool.ToolRepository -> Aff { latest :: Version, unstable :: Version }
fetchFromGitHubReleases repo = recover do
  page <- liftEffect (Ref.new 1)
  untilBothVersionsFound \firstUnstableVersion -> do
    versions <- liftEffect (Ref.read page) >>= toolVersions repo
    case versions of
      Just versions' -> do
        let
          unstable = firstUnstableVersion <|> Array.head versions'
          latest = versions' # Array.find \v ->
            (not $ Version.isPreRelease v) && (List.null $ Version.buildMetadata v)
        case latest of
          Nothing -> do
            liftEffect $ void $ Ref.modify (_ + 1) page
            pure $ Left unstable
          Just v -> do
            pure $ Right
              { latest: v
              , unstable: fromMaybe v unstable
              }

      Nothing ->
        case firstUnstableVersion of
          Nothing ->
            throwError $ error "Could not find a pre-release or stable version"
          Just _ ->
            throwError $ error "Could not find version that is not a pre-release version"
  where
  -- based on `untilJust`
  untilBothVersionsFound :: forall a b m. MonadRec m => (Maybe a -> m (Either (Maybe a) b)) -> m b
  untilBothVersionsFound f = Nothing # tailRecM \mb1 -> f mb1 <#> case _ of
    Left mb2 -> Loop mb2
    Right x -> Done x

toolVersions :: Tool.ToolRepository -> Int -> Aff (Maybe (Array Version))
toolVersions repo page = do
  let
    url =
      "https://api.github.com/repos/"
        <> repo.owner
        <> "/"
        <> repo.name
        <> "/releases?per_page=10&page="
        <> show page

  Affjax.Node.get Affjax.ResponseFormat.json url >>= case _ of
    Left err -> throwError (error $ Affjax.Node.printError err)
    Right { body } -> case decodeJson body of
      Left e -> do
        throwError $ error
          $ fold
              [ "Failed to decode GitHub response. This is most likely due to a timeout.\n\n"
              , printJsonDecodeError e
              , stringifyWithIndent 2 body
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
                  Left _ -> do
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
                      pure
                        if isDraft then Nothing
                        else Just version

tagStrToVersion :: String -> Either ParseError Version
tagStrToVersion tagStr =
  tagStr
    # String.stripPrefix (String.Pattern "v")
    # fromMaybe tagStr
    # Version.parseVersion

-- If a tool doesn't use GitHub releases and instead only tags versions, then
-- we have to fetch the tags, parse them as appropriate versions, and then sort
-- them according to their semantic version to get the latest one.
fetchFromGitHubTags :: Tool.ToolRepository -> Aff { latest :: Version, unstable :: Version }
fetchFromGitHubTags repo = recover do
  let url = "https://api.github.com/repos/" <> repo.owner <> "/" <> repo.name <> "/tags"

  Affjax.Node.get Affjax.ResponseFormat.json url >>= case _ of
    Left err -> do
      throwError (error $ Affjax.Node.printError err)

    Right { body } -> case traverse (_ .: "name") =<< decodeJson body of
      Left e -> do
        throwError $ error $ fold
          [ "Failed to decode GitHub response. This is most likely due to a timeout.\n\n"
          , printJsonDecodeError e
          , stringifyWithIndent 2 body
          ]

      Right arr -> do
        let
          tags = Array.mapMaybe (tagStrToVersion >>> hush) arr

        case maximum tags of
          Nothing ->
            throwError $ error "Could not download latest release version."

          Just v ->
            pure { latest: v, unstable: v }

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
