-- | Exports functions from the @actions/core module provided by GitHub
-- | https://github.com/actions/toolkit/tree/main/packages/core
module Actions.Core 
  ( addPath
  , debug
  , error
  , exportVariable
  , getInput
  , info
  , setFailed
  , warning
  ) where

import Prelude

import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Setup.Data.Key (Key)

-- | Prepends input path to the PATH (for this action and future actions)
foreign import addPath :: String -> Effect Unit

-- | Writes debug message to user log
foreign import debug :: String -> Effect Unit

-- | Writes error message to user log
foreign import error :: String -> Effect Unit

-- | Sets env variable for this action and future actions in the job
foreign import exportVariable :: { key :: String, value :: String } -> Effect Unit

foreign import getInputImpl :: Key -> Effect (Nullable String)

-- | Gets the value of an input. The value is also trimmed.
getInput :: Key -> Effect (Maybe String)
getInput = map toMaybe <<< getInputImpl

-- | Writes info message to user log
foreign import info :: String -> Effect Unit

-- | Sets the action status to failed. When the action exits it will be with an
-- | exit code of 1
foreign import setFailed :: String -> Effect Unit

-- | Writes warning message to user log
foreign import warning :: String -> Effect Unit
