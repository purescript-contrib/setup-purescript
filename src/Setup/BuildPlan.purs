module Setup.BuildPlan (buildPlan, BuildPlan) where

import Prelude

import Actions.Core as Core
import Affjax as AX
import Affjax.ResponseFormat as RF
import Data.Argonaut.Core (stringify)
import Data.Argonaut.Decode (decodeJson, printJsonDecodeError, (.:))
import Data.Array as Array
import Data.Bifunctor (bimap)
import Data.Either (Either(..), hush)
import Data.Foldable (elem, fold)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String as String
import Data.Traversable (traverse)
import Data.Version (Version)
import Data.Version as Version
import Effect (Effect)
import Effect.Aff (Aff, Error, Milliseconds(..), delay, error, throwError)
import Effect.Aff.Retry (RetryPolicy, RetryPolicyM, RetryStatus(..))
import Effect.Aff.Retry as Retry
import Effect.Class (liftEffect)
import Math (pow)
import Setup.Data.Key (Key)
import Setup.Data.Key as Key
import Setup.Data.Tool (Tool(..))
import Setup.Data.Tool as Tool
import Text.Parsing.Parser (parseErrorMessage)
import Text.Parsing.Parser as ParseError

-- | The list of tools that should be downloaded and cached by the action
type BuildPlan = Array { tool :: Tool, version :: Version }

-- | Construct the list of tools that sholud be downloaded and cached by the action
buildPlan :: Aff BuildPlan
buildPlan = do 
  let resolve' t = delay (Milliseconds 250.0) *> resolve t 
  map Array.catMaybes $ traverse resolve' [ PureScript, Spago, Purty, Zephyr ]

-- Tools that are required in the toolchain
required :: Tool -> Boolean
required tool = elem tool [ PureScript, Spago ]

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
resolve :: Tool -> Aff (Maybe { tool :: Tool, version :: Version })
resolve tool = do
  let key = Key.fromTool tool
  liftEffect (getVersionField key) >>= case _ of
    Nothing | required tool -> throwError $ error "No input received for required key."
    Nothing -> pure Nothing
    Just field -> map Just $ getVersion field
  
  where
  getVersion :: Either String VersionField -> Aff { tool :: Tool, version :: Version }
  getVersion = case _ of
    Left err -> do
      liftEffect $ Core.setFailed $ fold [ "Unable to parse version: ", err ]
      throwError $ error "Unable to complete fetching version."
    
    Right (Exact v) -> do
      liftEffect $ Core.info "Found exact version"
      pure { tool, version: v }

    Right Latest -> do
      liftEffect $ Core.info $ fold [ "Fetching latest tag for ", Tool.name tool ]
      v <- fetchLatestReleaseVersion
      pure { tool, version: v }
    
  -- Find the latest release version for a given tool. Prefers explicit releases
  -- as listed in GitHub releases, but for tools which don't support GitHub
  -- releases, falls back to the highest valid semantic version tag for the tool.
  fetchLatestReleaseVersion :: Aff Version
  fetchLatestReleaseVersion = Tool.repository tool # case tool of
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
            throwError $ error $ fold 
              [ "Failed to decode GitHub response. This is most likely due to a timeout.\n\n"
              , printJsonDecodeError e
              , stringify body
              ]

          Right tagStr -> do
            let tag = fromMaybe tagStr (String.stripPrefix (String.Pattern "v") tagStr)
            case Version.parseVersion tag of
              Left e ->
                throwError $ error $ fold 
                  [ "Failed to decode tag from GitHub response: ", parseErrorMessage e ]

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
            throwError $ error $ fold 
              [ "Failed to decode GitHub response. This is most likely due to a timeout.\n\n"
              , printJsonDecodeError e
              , stringify body
              ]

          Right arr -> do
            let 
              tags = Array.catMaybes $ map (\t -> hush $ Version.parseVersion $ fromMaybe t $ String.stripPrefix (String.Pattern "v") t) arr
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
    policy = exponentialBackoff (Milliseconds 5000.0) <> Retry.limitRetries 3

    checks :: Array (RetryStatus -> Error -> Aff Boolean)
    checks = [ \_ -> \_ -> pure true ]

    exponentialBackoff :: Milliseconds -> RetryPolicy
    exponentialBackoff (Milliseconds base) = 
      Retry.retryPolicy 
        \(RetryStatus { iterNumber: n }) ->
          Just $ Milliseconds $ base * pow 3.0 (toNumber n)
