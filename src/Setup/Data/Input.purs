-- | Action inputs, as specified by the 'inputs' key of the action.yml file.
module Setup.Data.Input where

import Prelude

import Data.Bifunctor (bimap)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Version (Version)
import Data.Version as Version
import Setup.Data.Tool (Tool(..))
import Text.Parsing.Parser as ParseError

data Input = Version Tool

toKey :: Input -> String
toKey = case _ of
  Version PureScript -> "purescript-version"
  Version Spago -> "spago-version"
  Version Purty -> "purty-version"
  Version Zephyr -> "zephyr-version"

data VersionField = Latest | Exact Version

parseVersionField :: Maybe String -> Either String VersionField 
parseVersionField = case _ of
  Nothing -> Left "No input value provided."
  Just str | str == "latest" -> pure Latest
  Just str ->
    bimap ParseError.parseErrorMessage Exact (Version.parseVersion str)