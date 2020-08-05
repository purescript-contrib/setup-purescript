module Main where

import Prelude

import Data.Argonaut.Core (Json)
import Data.Foldable (traverse_)
import Effect (Effect)
import Effect.Aff (launchAff_)
import Setup.BuildPlan (constructBuildPlan)
import Setup.Download (download)
import Setup.UpdateVersions (updateVersions)

main :: Json -> Effect Unit
main json = do 
  plan <- constructBuildPlan json
  launchAff_ $ traverse_ download plan

update :: Effect Unit
update = launchAff_ updateVersions