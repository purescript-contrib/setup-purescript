module Main where

import Prelude

import Data.Foldable (traverse_)
import Effect (Effect)
import Effect.Aff (launchAff_)
import Setup.BuildPlan (buildPlan)
import Setup.Download (download)

main :: Effect Unit
main = launchAff_ do 
  -- Decide what tools to build
  plan <- buildPlan 

  -- Build and cache the tools
  traverse_ download plan
