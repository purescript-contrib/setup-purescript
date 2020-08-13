-- | Exports functions from the @actions/exec module provided by GitHub
-- | https://github.com/actions/toolkit/tree/main/packages/exec
module Actions.Exec
  ( exec
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Effect.Aff (Aff)
import Effect.Uncurried (EffectFn2, runEffectFn2)

foreign import execImpl :: EffectFn2 String (Array String) (Promise Number)

-- | Executes a command on the command line, with arguments
exec :: String -> Array String -> Aff { succeeded :: Boolean }
exec command args =
  map ((_ == 0.0) >>> { succeeded: _ })
    $ toAffE
    $ runEffectFn2 execImpl command args
