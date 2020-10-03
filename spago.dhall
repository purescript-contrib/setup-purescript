{ name = "setup-purescript"
, dependencies =
  [ "aff"
  , "aff-promise"
  , "aff-retry"
  , "affjax"
  , "argonaut-codecs"
  , "argonaut-core"
  , "console"
  , "debug"
  , "effect"
  , "github-actions-toolkit"
  , "monad-loops"
  , "node-fs"
  , "node-path"
  , "node-process"
  , "nullable"
  , "psci-support"
  , "record"
  , "versions"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs" ]
}
