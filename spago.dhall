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
  , "node-fs"
  , "node-path"
  , "node-process"
  , "nullable"
  , "psci-support"
  , "purescript-github-actions-toolkit"
  , "record"
  , "versions"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
