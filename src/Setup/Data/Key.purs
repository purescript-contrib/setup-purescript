module Setup.Data.Key
  ( Key
  , fromTool
  ) where

import Data.Newtype (class Newtype)
import Setup.Data.Tool (Tool(..))

newtype Key = Key String

derive instance newtypeKey :: Newtype Key _

purescriptKey :: Key
purescriptKey = Key "purescript"

spagoKey :: Key
spagoKey = Key "spago"

psaKey :: Key
psaKey = Key "psa"

zephyrKey :: Key
zephyrKey = Key "zephyr"

fromTool :: Tool -> Key
fromTool = case _ of
  PureScript -> purescriptKey
  Spago -> spagoKey
  Psa -> psaKey
  Zephyr -> zephyrKey
