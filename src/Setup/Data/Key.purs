module Setup.Data.Key
  ( Key
  , fromTool
  ) where

import Setup.Data.Tool (Tool(..))

newtype Key = Key String

purescriptKey :: Key
purescriptKey = Key "purescript"

spagoKey :: Key
spagoKey = Key "spago"

psaKey :: Key
psaKey = Key "psa"

purtyKey :: Key
purtyKey = Key "purty"

zephyrKey :: Key
zephyrKey = Key "zephyr"

fromTool :: Tool -> Key
fromTool = case _ of
  PureScript -> purescriptKey
  Spago -> spagoKey
  Psa -> psaKey
  Purty -> purtyKey
  Zephyr -> zephyrKey
