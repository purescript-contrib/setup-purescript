module Setup.Data.VersionsFile where

import Prelude

import Control.Monad.Error.Class (throwError)
import Data.Argonaut.Core (Json, stringify)
import Data.Argonaut.Decode (printJsonDecodeError)
import Data.Argonaut.Decode as Json
import Data.Either (Either(..))
import Effect (Effect)
import Effect.Exception (error)
import Node.Encoding (Encoding(..))
import Node.FS.Sync (readTextFile, writeTextFile)
import Node.Path (FilePath)

path = "./dist/versions.json" :: FilePath

writeVersionsFile :: Json -> Effect Unit
writeVersionsFile = writeTextFile UTF8 path <<< stringify

readVersionsFile :: Effect Json
readVersionsFile = do 
  str <- readTextFile UTF8 path
  case Json.parseJson str of
    Left e ->
      throwError $ error $ printJsonDecodeError e
    Right v ->
      pure v