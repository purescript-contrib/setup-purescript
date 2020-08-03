module Main where

import Prelude

import Data.Foldable (traverse_)
import Effect (Effect)
import Effect.Aff (launchAff_)
import Setup.Data.Tool (Tool(..))
import Setup.DownloadTool (downloadTool)

main :: Effect Unit
main = launchAff_ $ traverse_ downloadTool [ PureScript, Spago, Purty, Zephyr ]