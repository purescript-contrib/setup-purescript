module Setup.Data.Tool where

import Prelude

import Data.Foldable (elem, fold)
import Data.Version (Version)
import Data.Version as Version
import Setup.Data.Platform (Platform(..), platform)

data Tool 
  = PureScript
  | Spago
  | Purty
  | Zephyr

derive instance eqTool :: Eq Tool

name :: Tool -> String
name = case _ of
  PureScript -> "purs"
  Spago -> "spago"
  Purty -> "purty"
  Zephyr -> "zephyr"

tarballSource :: Tool -> Version -> String
tarballSource tool version = repository tool # case tool of
  PureScript -> formatGitHub
  Spago -> formatGitHub
  Purty -> formatBintrayPurty
  Zephyr -> formatGitHub
  where
  formatGitHub repo =
    -- Example: https://github.com/purescript/purescript/releases/download/v0.13.8/win64.tar.gz
    fold 
      [ "https://github.com/"
      , repo.owner
      , "/"
      , repo.name
      , "/releases/download/" 
      , formatTag tool version
      , "/"
      , formatTarball tool 
      ]
  
  -- Purty uses Bintray, and a non-standard path to binaries, so this has to be
  -- special-cased.
  formatBintrayPurty repo =
    -- Example: https://dl.bintray.com/joneshf/generic/:purty-6.2.0-linux.tar.gz
    fold 
      [ "https://dl.bintray.com/"
      , repo.owner
      , "/generic/"
      , repo.name
      , "-"
      , formatTag tool version
      , "-"
      , formatTarball tool
      ]

-- | Format the release tag for a tool at a specific version. Not all tools use
-- | the same format.
-- |
-- | Example: "v0.13.2", "0.15.2"
formatTag :: Tool -> Version -> String
formatTag tool version = do
  let versionStr = Version.showVersion version
  if tool `elem` [ PureScript, Zephyr] then 
    fold [ "v", versionStr ]
  else
    versionStr

-- | Format the tarball name for a given tool and platform. Each tool uses a
-- | different naming convention.
-- |
-- | Example: "win64.tar.gz", "Windows.tar.gz"
formatTarball :: Tool -> String
formatTarball tool = binaryName <> ".tar.gz"
  where
  binaryName = case platform, tool of
    Windows, PureScript -> "win64"
    Windows, Spago -> "windows"
    Windows, Purty -> "win"
    Windows, Zephyr -> "Windows"

    Mac, PureScript -> "macos"
    Mac, Spago -> "osx"
    Mac, Purty -> "osx"
    Mac, Zephyr -> "macOS"

    Linux, PureScript -> "linux64"
    Linux, Spago -> "linux"
    Linux, Purty -> "linux"
    Linux, Zephyr -> "Linux"

type ToolRepository = { owner :: String, name :: String }

repository :: Tool -> ToolRepository
repository = case _ of
  PureScript ->
    { owner: "purescript", name: "purescript" }
  Spago ->
    { owner: "purescript", name: "spago" }
  Purty ->
    { owner: "joneshf", name: "purty" }
  Zephyr ->
    { owner: "coot", name: "zephyr" }
