module Main where

import Prelude

import Control.Monad.Except.Trans (mapExceptT, runExceptT)
import Data.Argonaut.Core (Json)
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Effect (Effect)
import Effect.Aff (launchAff_, runAff_)
import Effect.Class (liftEffect)
import Effect.Exception (message)
import GitHub.Actions.Core as Core
import Setup.BuildPlan (constructBuildPlan)
import Setup.GetTool (getTool)
import Setup.UpdateVersions (updateVersions)

main :: Json -> Effect Unit
main json = runAff_ go $ runExceptT do
  tools <- mapExceptT liftEffect $ constructBuildPlan json
  liftEffect $ Core.info "Constructed build plan."
  traverse_ getTool tools
  liftEffect $ Core.info "Fetched tools."
  where
  go res = case join res of
    Left err -> Core.setFailed (message err)
    Right a -> pure unit

update :: Effect Unit
update = launchAff_ updateVersions
