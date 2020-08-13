module Setup.Data.Tool where

import Prelude

import Affjax (URL)
import Data.Enum (class Enum, upFromIncluding)
import Data.Foldable (elem, fold)
import Data.Generic.Rep (class Generic)
import Data.Generic.Rep.Bounded (genericBottom, genericTop)
import Data.Generic.Rep.Enum (genericPred, genericSucc)
import Data.Version (Version)
import Data.Version as Version
import Node.Path (FilePath)
import Node.Path as Path
import Setup.Data.Platform (Platform(..), platform)

data Tool
  = PureScript
  | Spago
  | Psa
  | Purty
  | Zephyr

derive instance eqTool :: Eq Tool
derive instance ordTool :: Ord Tool
derive instance genericTool :: Generic Tool _

instance boundedTool :: Bounded Tool where
  bottom = genericBottom
  top = genericTop

instance enumTool :: Enum Tool where
  succ = genericSucc
  pred = genericPred

-- | A list of all available tools in the toolchain
allTools :: Array Tool
allTools = upFromIncluding bottom

-- | Tools that are required in the toolchain
requiredTools :: Array Tool
requiredTools = [ PureScript, Spago ]

-- | Tools that are required in the toolchain
required :: Tool -> Boolean
required tool = elem tool requiredTools

name :: Tool -> String
name = case _ of
  PureScript -> "purs"
  Spago -> "spago"
  Psa -> "psa"
  Purty -> "purty"
  Zephyr -> "zephyr"

-- | The source repository for a tool (whether on GitHub or Gitlab)
type ToolRepository = { owner :: String, name :: String }

repository :: Tool -> ToolRepository
repository = case _ of
  PureScript ->
    { owner: "purescript", name: "purescript" }

  Spago ->
    { owner: "purescript", name: "spago" }

  Psa ->
    { owner: "natefaubion", name: "purescript-psa" }

  Purty ->
    { owner: "joneshf", name: "purty" }

  Zephyr ->
    { owner: "coot", name: "zephyr" }

-- | How a tool will be installed: either a tarball from a URL, or an NPM package
-- | at a particular version.
data InstallMethod = Tarball TarballOpts | NPM NPMPackage

-- | The source used to download a tarball and its path inside the extracted
-- | directory.
type TarballOpts =
  { source :: URL
  , getExecutablePath :: FilePath -> FilePath
  }

-- | An NPM package. Example: "purescript-psa@0.7.2"
type NPMPackage = String

-- | The installation method for a tool, which includes the source path necessary
-- | to download or install the tool.
installMethod :: Tool -> Version -> InstallMethod
installMethod tool version = do
  let
    toolName = name tool
    toolRepo = repository tool
    formatArgs = { repo: toolRepo, tag: formatTag, tarball: _ }

    formatGitHub' = formatGitHub <<< formatArgs
    formatBintray' = formatBintray <<< formatArgs

    executableName = case platform of
      Windows -> toolName <> ".exe"
      _ -> toolName

  case tool of
    PureScript -> Tarball
      { source: formatGitHub' case platform of
          Windows -> "win64"
          Mac -> "macos"
          Linux -> "linux64"
      , getExecutablePath: \p -> Path.concat [ p, "purescript", executableName ]
      }

    Spago -> Tarball
      { source: formatGitHub' $ case platform of
          Windows -> "windows"
          Mac -> "osx"
          Linux -> "linux"
      , getExecutablePath: \p -> Path.concat [ p, executableName ]
      }

    Psa ->
      NPM (toolRepo.name <> "@" <> Version.showVersion version)

    Purty -> Tarball
      { source: formatBintray' $ case platform of
          Windows -> "win"
          Mac -> "osx"
          Linux -> "linux"
      , getExecutablePath: \p -> Path.concat [ p, executableName ]
      }

    Zephyr -> Tarball
      { source: formatGitHub' $ case platform of
          Windows -> "Windows"
          Mac -> "macOS"
          Linux -> "Linux"
      , getExecutablePath: \p -> Path.concat [ p, "zephyr", executableName ]
      }

  where
  -- Format the release tag for a tool at a specific version. Not all tools use
  -- the same format.
  --
  -- Example: "v0.13.2", "0.15.2"
  formatTag :: String
  formatTag = do
    let versionStr = Version.showVersion version
    if tool `elem` [ PureScript, Zephyr, Psa ] then
      fold [ "v", versionStr ]
    else
      versionStr

  formatGitHub :: { repo :: ToolRepository, tag :: String, tarball :: String } -> String
  formatGitHub { repo, tag, tarball } =
    -- Example: https://github.com/purescript/purescript/releases/download/v0.13.8/win64.tar.gz
    fold
      [ "https://github.com/"
      , repo.owner
      , "/"
      , repo.name
      , "/releases/download/"
      , tag
      , "/"
      , tarball
      , ".tar.gz"
      ]

  formatBintray :: { repo :: ToolRepository, tag :: String, tarball :: String } -> String
  formatBintray { repo, tag, tarball } =
    -- Example: https://dl.bintray.com/joneshf/generic/purty-6.2.0-linux.tar.gz
    fold
      [ "https://dl.bintray.com/"
      , repo.owner
      , "/generic/"
      , repo.name
      , "-"
      , tag
      , "-"
      , tarball
      , ".tar.gz"
      ]
