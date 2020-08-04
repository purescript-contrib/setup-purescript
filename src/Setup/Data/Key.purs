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

purtyKey :: Key
purtyKey = Key "purty"

zephyrKey :: Key
zephyrKey = Key "zephyr"

fromTool :: Tool -> Key
fromTool = case _ of
  PureScript -> purescriptKey
  Spago -> spagoKey
  Purty -> purtyKey
  Zephyr -> zephyrKey
