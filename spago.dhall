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
  , "node-path"
  , "node-process"
  , "nullable"
  , "psci-support"
  , "record"
  , "versions"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
