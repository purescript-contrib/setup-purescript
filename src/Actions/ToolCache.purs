-- | Exports functions from the @actions/tool-cache module provided by GitHub
-- | https://github.com/actions/toolkit/tree/main/packages/tool-cache
module Actions.ToolCache 
  ( CacheOptions
  , cacheDir
  , cacheFile
  , downloadTool
  , downloadTool'
  , extractTar
  , extractTar'
  , find
  ) where

import Prelude

import Control.Promise (Promise, toAffE)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.String as String
import Data.Version (Version)
import Data.Version as Version
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Uncurried (EffectFn2, EffectFn3, EffectFn4, runEffectFn2, runEffectFn3, runEffectFn4)
import Node.Path (FilePath)
import Setup.Data.Tool (Tool)
import Setup.Data.Tool as Tool

type ToolName = String

type CacheOptions =
  { source :: FilePath
  , tool :: Tool
  , version :: Version 
  }

foreign import cacheDirImpl :: EffectFn3 FilePath ToolName String (Promise FilePath)

-- | Caches a directory and installs it into the tool cacheDir
cacheDir :: CacheOptions -> Aff FilePath
cacheDir { source, tool, version } = do 
  let 
    toolName = Tool.name tool
    version' = Version.showVersion version

  toAffE (runEffectFn3 cacheDirImpl source toolName version')

foreign import cacheFileImpl :: EffectFn4 FilePath String ToolName String (Promise FilePath)

-- | Caches a downloaded file (GUID) and installs it into the tool cache
cacheFile :: CacheOptions -> Aff FilePath 
cacheFile { source, tool, version } = do
  let 
    toolName = Tool.name tool
    version' = Version.showVersion version

  -- We use the same name for the `targetName` and the `toolName` as the tool
  -- name is the executable name.
  toAffE (runEffectFn4 cacheFileImpl source toolName toolName version')

foreign import downloadToolImpl :: EffectFn2 String (Nullable String) (Promise FilePath)

-- | Download a tool from a URL and stream it into a file, returning the file path
downloadTool' :: String -> Aff FilePath
downloadTool' url = toAffE (runEffectFn2 downloadToolImpl url null)

-- | Download a tool from an url and stream it into the destination file path, 
-- | returning the file path
downloadTool :: String -> FilePath -> Aff FilePath
downloadTool url dest = toAffE (runEffectFn2 downloadToolImpl url (notNull dest))

foreign import extractTarImpl :: EffectFn2 FilePath (Nullable FilePath) (Promise FilePath)

-- | Extract a compressed tar archive, returning the resulting file path
extractTar' :: FilePath -> Aff FilePath
extractTar' src = toAffE (runEffectFn2 extractTarImpl src null)

-- | Extract a compressed tar archive to a target destination, returning the 
-- | resulting file path
extractTar :: FilePath -> FilePath -> Aff FilePath
extractTar src dest = toAffE (runEffectFn2 extractTarImpl src (notNull dest))

foreign import findImpl :: ToolName -> String -> Effect (Nullable FilePath)

-- | Finds the path to a tool version in the local installed tool cache
find :: Tool -> Version -> Effect (Maybe FilePath)
find tool version = do 
  let 
    toolName = Tool.name tool
    toolVersion = Version.showVersion version 
    checkNull fp
      | String.null fp = Nothing
      | otherwise = Just fp
   
  map (checkNull <=< toMaybe) (findImpl toolName toolVersion)
