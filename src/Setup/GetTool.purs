module Setup.GetTool (getTool) where

import Prelude

import Data.Foldable (fold)
import Data.Maybe (Maybe(..))
import Data.Version (Version)
import Data.Version as Version
import Effect.Class (liftEffect)
import GitHub.Actions.Core as Core
import GitHub.Actions.Exec as Exec
import GitHub.Actions.ToolCache as ToolCache
import GitHub.Actions.Types (ActionsM)
import Setup.Data.Platform (Platform(..), platform)
import Setup.Data.Tool (InstallMethod(..), Tool)
import Setup.Data.Tool as Tool

getTool :: { tool :: Tool, version :: Version } -> ActionsM Unit
getTool { tool, version } = do
  let
    name = Tool.name tool
    installMethod = Tool.installMethod tool version

  case installMethod of
    Tarball opts -> do
      ToolCache.find { arch: Nothing, toolName: name, versionSpec: Version.showVersion version } >>= case _ of
        Just path -> liftEffect do
          Core.info $ fold [ "Found cached version of ", name ]
          Core.addPath path

        Nothing -> do
          liftEffect do
            Core.info $ fold [ "Did not find cached version of ", name ]

          downloadPath <- ToolCache.downloadTool { url: opts.source, auth: Nothing, dest: Nothing  }
          extractedPath <- ToolCache.extractTar { file: downloadPath, dest: Nothing, flags: Nothing }
          cached <- ToolCache.cacheFile { sourceFile: opts.getExecutablePath extractedPath, tool: name, version: version, targetFile: name, arch: Nothing }

          liftEffect do
            Core.info $ fold [ "Cached path ", cached, ", adding to PATH" ]
            Core.addPath cached

    NPM package -> void $ case platform of
      Windows ->
        Exec.exec "npm" [ "install", "-g", package ] Nothing
      _ ->
        Exec.exec "sudo npm" [ "install", "-g", package ] Nothing
