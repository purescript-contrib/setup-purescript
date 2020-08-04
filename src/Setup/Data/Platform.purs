module Setup.Data.Platform where

import Data.Maybe (Maybe(..))
import Node.Platform as Platform
import Node.Process as Process

data Platform = Windows | Mac | Linux

-- | Parse a platform value from the `process.platform` key
platform :: Platform
platform = case Process.platform of 
  Just Platform.Win32 -> Windows
  Just Platform.Darwin -> Mac
  _ -> Linux
