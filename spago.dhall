{ name = "setup-purescript"
, dependencies =
  [ "aff"
  , "aff-promise"
  , "aff-retry"
  , "affjax"
  , "argonaut-codecs"
  , "argonaut-core"
  , "console"
  , "effect"
  , "github-actions-toolkit"
  , "node-fs"
  , "node-path"
  , "node-process"
  , "nullable"
  , "psci-support"
  , "record"
  , "versions"
  , "monad-loops"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
