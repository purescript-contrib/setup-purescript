module Setup.Data.VersionField (VersionField(..), showVersionField) where

import Data.Version (Version)
import Data.Version as Version

-- | The parsed value of an input field that specifies a version
data VersionField = Latest | Exact Version

showVersionField :: VersionField -> String
showVersionField = case _ of
  Latest -> "latest"
  Exact v -> Version.showVersion v
