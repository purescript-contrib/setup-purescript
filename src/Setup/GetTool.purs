module Setup.GetTool (getTool) where

import Prelude

import Actions.Core as Core
import Actions.Exec as Exec
import Actions.ToolCache as ToolCache
import Data.Foldable (fold)
import Data.Maybe (Maybe(..))
import Data.Version (Version)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Setup.Data.Platform (Platform(..), platform)
import Setup.Data.Tool (InstallMethod(..), Tool)
import Setup.Data.Tool as Tool

getTool :: { tool :: Tool, version :: Version } -> Aff Unit
getTool { tool, version } = do
  let
    name = Tool.name tool
    installMethod = Tool.installMethod tool version

  case installMethod of
    Tarball opts -> do
      liftEffect (ToolCache.find tool version) >>= case _ of
        Just path -> liftEffect do
          Core.info $ fold [ "Found cached version of ", name ]
          Core.addPath path

        Nothing -> do
          liftEffect $ Core.info $ fold [ "Did not find cached version of ", name ]

          downloadPath <- ToolCache.downloadTool' opts.source
          extractedPath <- ToolCache.extractTar' downloadPath
          cached <- ToolCache.cacheFile { source: opts.getExecutablePath extractedPath, tool, version }

          liftEffect do
            Core.info $ fold [ "Cached path ", cached, ", adding to PATH" ]
            Core.addPath cached

    NPM package -> void $ case platform of
      Windows ->
        Exec.exec "npm" [ "install", "-g", package ]
      _ ->
        Exec.exec "sudo npm" [ "install", "-g", package ]
