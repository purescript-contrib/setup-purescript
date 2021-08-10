module Setup.GetTool (getTool) where

import Prelude

import Control.Monad.Except.Trans (ExceptT, mapExceptT)
import Data.Foldable (fold)
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Exception (Error)
import GitHub.Actions.Core as Core
import GitHub.Actions.Exec as Exec
import GitHub.Actions.ToolCache as ToolCache
import Setup.Data.Platform (Platform(..), platform)
import Setup.Data.Tool (InstallMethod(..), Tool)
import Setup.Data.Tool as Tool
import Setup.Data.VersionField (VersionField)
import Setup.Data.VersionField as VersionField

getTool :: { tool :: Tool, versionField :: VersionField } -> ExceptT Error Aff Unit
getTool { tool, versionField } = do
  let
    name = Tool.name tool
    installMethod = Tool.installMethod tool versionField

  liftEffect $ Core.info $ fold [ "Fetching ", name ]

  case installMethod of
    Tarball opts -> do
      mbPath <- mapExceptT liftEffect $ ToolCache.find { arch: Nothing, toolName: name, versionSpec: VersionField.showVersionField versionField }
      case mbPath of
        Just path -> liftEffect do
          Core.info $ fold [ "Found cached version of ", name ]
          Core.addPath path

        Nothing -> do
          downloadPath <- ToolCache.downloadTool' opts.source
          extractedPath <- ToolCache.extractTar' downloadPath
          cached <- ToolCache.cacheFile { sourceFile: opts.getExecutablePath extractedPath, tool: name, version: VersionField.showVersionField versionField, targetFile: name, arch: Nothing }

          liftEffect do
            Core.info $ fold [ "Cached path ", cached, ", adding to PATH" ]
            Core.addPath cached

    NPM package -> void $ case platform of
      Windows ->
        Exec.exec { command: "npm", args: Just [ "install", "-g", package ], options: Nothing }
      _ ->
        Exec.exec { command: "sudo npm", args: Just [ "install", "-g", package ], options: Nothing }
