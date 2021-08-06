module Main where

import Prelude

import Affjax (printError)
import Affjax as AX
import Affjax.ResponseFormat as RF
import Control.Monad.Except.Trans (ExceptT(..), mapExceptT, runExceptT)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Effect (Effect)
import Effect.Aff (error, launchAff_, runAff_)
import Effect.Class (liftEffect)
import Effect.Exception (message)
import GitHub.Actions.Core as Core
import Setup.BuildPlan (constructBuildPlan)
import Setup.GetTool (getTool)
import Setup.UpdateVersions (updateVersions)

main :: Effect Unit
main = runAff_ go $ runExceptT do
  versionsJson <- ExceptT $ map (lmap (error <<< printError)) $ AX.get RF.json versionsFile
  tools <- mapExceptT liftEffect $ constructBuildPlan versionsJson.body
  liftEffect $ Core.info "Constructed build plan."
  traverse_ getTool tools
  liftEffect $ Core.info "Fetched tools."
  where
  versionsFile = "https://raw.githubusercontent.com/purescript-contrib/setup-purescript/main/dist/versions.json"

  go res = case join res of
    Left err -> Core.setFailed (message err)
    Right _ -> pure unit

update :: Effect Unit
update = launchAff_ updateVersions
