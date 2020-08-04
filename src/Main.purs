module Main where

import Prelude

import Data.Foldable (traverse_)
import Effect (Effect)
import Effect.Aff (launchAff_)
import Setup.BuildPlan (constructBuildPlan)
import Setup.Download (download)
import Setup.UpdateVersions (updateVersions)

main :: Effect Unit
main = do 
  plan <- constructBuildPlan 
  launchAff_ $ traverse_ download plan

update :: Effect Unit
update = launchAff_ updateVersions