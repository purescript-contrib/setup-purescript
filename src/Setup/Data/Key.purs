module Setup.Data.Key
  ( Key
  , fromTool
  , toString
  ) where

import Setup.Data.Tool (Tool(..))

newtype Key = Key String

purescriptKey :: Key
purescriptKey = Key "purescript"

spagoKey :: Key
spagoKey = Key "spago"

psaKey :: Key
psaKey = Key "psa"

pursTidyKey :: Key
pursTidyKey = Key "purs-tidy"

zephyrKey :: Key
zephyrKey = Key "zephyr"

toString :: Key -> String
toString (Key key) = key

fromTool :: Tool -> Key
fromTool = case _ of
  PureScript -> purescriptKey
  Spago -> spagoKey
  Psa -> psaKey
  PursTidy -> pursTidyKey
  Zephyr -> zephyrKey
