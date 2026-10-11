{ name = "setup-purescript-smoke"
, dependencies = [ "console", "effect", "prelude" ]
, packages =
    https://github.com/purescript/package-sets/releases/download/psc-0.15.15-20261009/packages.dhall
, sources = [ "src/**/*.purs" ]
}
