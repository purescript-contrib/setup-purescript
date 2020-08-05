module Setup.Data.VersionsFile where

import Prelude

import Data.Argonaut.Core (Json, stringify)
import Effect (Effect)
import Node.Encoding (Encoding(..))
import Node.FS.Sync (writeTextFile)
import Node.Path (FilePath)

path = "./dist/versions.json" :: FilePath

writeVersionsFile :: Json -> Effect Unit
writeVersionsFile = writeTextFile UTF8 path <<< stringify