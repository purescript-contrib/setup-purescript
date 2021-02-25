module Main where

import Prelude

import Control.Monad.Except.Trans (ExceptT(..), mapExceptT, runExceptT)
import Data.Argonaut.Parser as Json
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Effect (Effect)
import Effect.Aff (error, launchAff_, runAff_)
import Effect.Class (liftEffect)
import Effect.Exception (message)
import GitHub.Actions.Core as Core
import Node.Buffer as Buffer
import Node.Encoding (Encoding(..))
import Node.FS.Sync (readFile)
import Setup.BuildPlan (constructBuildPlan)
import Setup.GetTool (getTool)
import Setup.UpdateVersions (updateVersions)

main :: Effect Unit
main = runAff_ go $ runExceptT do
  versionsString <- liftEffect $ Buffer.toString UTF8 =<< readFile "./versions.json"
  versionsJson <- ExceptT $ pure $ lmap error $ Json.jsonParser versionsString
  tools <- mapExceptT liftEffect $ constructBuildPlan versionsJson
  liftEffect $ Core.info "Constructed build plan."
  traverse_ getTool tools
  liftEffect $ Core.info "Fetched tools."
  where
  go res = case join res of
    Left err -> Core.setFailed (message err)
    Right a -> pure unit

update :: Effect Unit
update = launchAff_ updateVersions
