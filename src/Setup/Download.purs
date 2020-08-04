module Setup.Download (download) where

import Prelude

import Actions.Core as Core
import Actions.ToolCache as ToolCache
import Data.Foldable (fold)
import Data.Maybe (Maybe(..))
import Data.Version (Version)
import Data.Version as Version
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Node.Path (FilePath)
import Node.Path as Path
import Setup.Data.Platform (Platform(..), platform)
import Setup.Data.Tool (Tool(..), tarballSource)
import Setup.Data.Tool as Tool

download :: { tool :: Tool, version :: Version } -> Aff Unit
download { tool, version } = do
  let name = Tool.name tool
  
  liftEffect (ToolCache.find tool version) >>= case _ of
    Just path -> liftEffect do
      Core.info $ fold 
        [ "Found cached version of "
        , name
        , " at version "
        , Version.showVersion version
        , " at path "
        , path
        , ", adding to PATH." 
        ]
      
      Core.addPath path
    
    Nothing -> do
      liftEffect $ Core.info $ fold 
        [ "Did not find cached version of "
        , name
        , " at version "
        , Version.showVersion version
        , ", downloading..." 
        ]
      
      executable <- downloadResolved tool version
      cached <- ToolCache.cacheFile { source: executable, tool, version }
      
      liftEffect do
        Core.info $ fold [ "Cached path ", cached, ", adding to PATH" ]
        Core.addPath cached

downloadResolved :: Tool -> Version -> Aff FilePath
downloadResolved tool version = do
  let source = tarballSource tool version
  liftEffect $ Core.info source
  downloadPath <- ToolCache.downloadTool' source
  extractedPath <- ToolCache.extractTar' downloadPath

  -- Construct the path to the executable itself
  let 
    executable = let name = Tool.name tool in case platform of
      Windows -> name <> ".exe"
      _ -> name
          
  pure $ Path.concat $ case tool of
    PureScript -> [ extractedPath, "purescript", executable ]
    Zephyr -> [ extractedPath, "zephyr", executable ]
    Purty -> [ extractedPath, executable ]
    Spago -> [ extractedPath, executable ]
