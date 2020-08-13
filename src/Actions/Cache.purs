-- | Exports functions from the @actions/cache module provided by GitHub
-- | https://github.com/actions/toolkit/tree/main/packages/cache
module Actions.Cache
  ( CacheKey
  , SaveCacheOptions
  , saveCache
  , RestoreCacheOptions
  , restoreCache
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Effect.Aff (Aff)
import Effect.Uncurried (EffectFn2, EffectFn3, runEffectFn2, runEffectFn3)
import Node.Path (FilePath)

type CacheKey = String

type SaveCacheOptions =
  { paths :: Array FilePath
  , primaryKey :: CacheKey
  }

foreign import saveCacheImpl :: EffectFn2 (Array FilePath) CacheKey (Promise Unit)

-- | Cache a list of files with the specified key
saveCache :: SaveCacheOptions -> Aff Unit
saveCache { paths, primaryKey } =
  toAffE (runEffectFn2 saveCacheImpl paths primaryKey)

foreign import restoreCacheImpl :: EffectFn3 (Array FilePath) CacheKey (Array CacheKey) (Promise Unit)

type RestoreCacheOptions =
  { paths :: Array FilePath
  , primaryKey :: CacheKey
  , restoreKeys :: Array String
  }

-- | Restore a cache from a primary key or fallback keys if the cache misses
restoreCache :: RestoreCacheOptions -> Aff Unit
restoreCache { paths, primaryKey, restoreKeys } =
  toAffE (runEffectFn3 restoreCacheImpl paths primaryKey restoreKeys)
