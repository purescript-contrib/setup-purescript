module Setup.Data.VersionFiles where

import Prelude

import Data.Argonaut.Core (Json, jsonEmptyObject)
import Data.Argonaut.Decode (JsonDecodeError(..), decodeJson, printJsonDecodeError)
import Data.Argonaut.Encode (encodeJson, (:=), (~>))
import Data.Array (fold)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.FoldableWithIndex (foldlWithIndex)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype)
import Data.TraversableWithIndex (forWithIndex)
import Data.Tuple (Tuple(..))
import Data.Version (Version)
import Data.Version as Version
import Foreign.Object (Object)
import Setup.Data.Tool (Tool(..))
import Parsing (ParseError)

latestVersion :: V2FileSchema
latestVersion = version2

data V2FileError
  = JsonCodecError JsonDecodeError
  | VersionParseError String ParseError
  | ToolNameError JsonDecodeError

printV2FileError :: V2FileError -> String
printV2FileError = case _ of
  JsonCodecError e -> printJsonDecodeError e
  VersionParseError field e -> fold
    [ "Version parse failure for key, "
    , field
    , "': "
    , show e
    ]
  ToolNameError e -> fold
    [ "Unable to convert String into Tool. "
    , printJsonDecodeError e
    ]

type LatestUnstable a =
  { latest :: a
  , unstable :: a
  }

newtype V2FileSchema = V2FileSchema
  { fileUrl :: String
  , localFile :: String
  , encode :: Map Tool (LatestUnstable Version) -> Json
  , decode :: Json -> Either V2FileError (Map Tool (LatestUnstable Version))
  }

derive instance Newtype V2FileSchema _

version2 :: V2FileSchema
version2 = V2FileSchema
  { fileUrl: "https://raw.githubusercontent.com/purescript-contrib/setup-purescript/main" <> filePath
  , localFile: "." <> filePath
  , encode: foldlWithIndex encodeFoldFn jsonEmptyObject
  , decode: \j -> do
      obj :: Object Json <- lmap JsonCodecError $ decodeJson j
      keyVals <- forWithIndex obj \key val -> do
        tool <- strToTool key
        { latest
        , unstable
        } :: LatestUnstable String <- lmap JsonCodecError $ decodeJson val
        latest' <- lmap (VersionParseError (key <> ".latest")) $ Version.parseVersion latest
        unstable' <- lmap (VersionParseError (key <> ".unstable")) $ Version.parseVersion unstable
        pure $ Tuple tool { latest: latest', unstable: unstable' }
      pure $ Map.fromFoldable keyVals
  }
  where
  filePath = "/dist/versions-v2.json"
  encodeFoldFn tool acc { latest, unstable }
    | Just toolStr <- toolToMbString tool = do
        let rec = { latest: Version.showVersion latest, unstable: Version.showVersion unstable }
        toolStr := rec ~> acc
    | otherwise =
        acc

  -- in case we add support for other tools in the future...
  toolToMbString = case _ of
    PureScript -> Just "purs"
    Spago -> Just "spago"
    Psa -> Just "psa"
    PursTidy -> Just "purs-tidy"
    Zephyr -> Just "zephyr"

  strToTool = case _ of
    "purs" -> Right PureScript
    "spago" -> Right Spago
    "psa" -> Right Psa
    "purs-tidy" -> Right PursTidy
    "zephyr" -> Right Zephyr
    str -> Left $ ToolNameError $ UnexpectedValue $ encodeJson str

newtype V1FileSchema = V1FileSchema
  { localFile :: String
  , encode :: Map Tool Version -> Json
  }

derive instance Newtype V1FileSchema _

version1 :: V1FileSchema
version1 = V1FileSchema
  { localFile: "./dist/versions.json"
  , encode: foldlWithIndex encodeFoldFn jsonEmptyObject
  }
  where
  encodeFoldFn tool acc version
    | Just toolStr <- printTool tool =
        toolStr := Version.showVersion version ~> acc
    | otherwise =
        acc

  -- We preserve the set of tools that existed at the time this version format was produced;
  -- if more tools are added, they should map to `Nothing`
  printTool = case _ of
    PureScript -> Just "purs"
    Spago -> Just "spago"
    Psa -> Just "psa"
    PursTidy -> Just "purs-tidy"
    Zephyr -> Just "zephyr"
