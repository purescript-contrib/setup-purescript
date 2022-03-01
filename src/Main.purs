module Main where

import Prelude

import Affjax (printError)
import Affjax as AX
import Affjax.ResponseFormat as RF
import Control.Monad.Except.Trans (ExceptT(..), runExceptT)
import Data.Argonaut.Parser (jsonParser)
import Data.Bifunctor (bimap, lmap)
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Data.Maybe (isJust)
import Effect (Effect)
import Effect.Aff (error, launchAff_, runAff_)
import Effect.Class (liftEffect)
import Effect.Exception (message)
import GitHub.Actions.Core as Core
import Node.Encoding (Encoding(..))
import Node.FS.Aff as FSA
import Node.Process as Process
import Setup.BuildPlan (constructBuildPlan)
import Setup.GetTool (getTool)
import Setup.UpdateVersions (updateVersions)

main :: Effect Unit
main = runAff_ go $ runExceptT do
  versionsJson <- getVersionsFile
  tools <- constructBuildPlan versionsJson
  liftEffect $ Core.info "Constructed build plan."
  traverse_ getTool tools
  liftEffect $ Core.info "Fetched tools."
  where
  getVersionsFile = ExceptT do
    mb <- liftEffect $ Process.lookupEnv "USE_LOCAL_VERSIONS_JSON"
    if isJust mb then do
      map (lmap error <<< jsonParser) $ FSA.readTextFile UTF8 "./dist/versions.json"
    else do
      map (bimap (error <<< printError) _.body) $ AX.get RF.json versionsFile

  versionsFile = "https://raw.githubusercontent.com/purescript-contrib/setup-purescript/main/dist/versions.json"

  go res = case join res of
    Left err -> Core.setFailed (message err)
    Right _ -> pure unit

update :: Effect Unit
update = launchAff_ updateVersions
