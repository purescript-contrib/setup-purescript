let upstream =
      https://github.com/purescript/package-sets/releases/download/psc-0.13.8-20200909/packages.dhall sha256:b899488adf6f02a92bbaae88039935bbc61bcba4cf4462f6d915fc3d0e094604

in  upstream
  with versions =
    { dependencies =
      [ "console"
      , "control"
      , "either"
      , "exceptions"
      , "foldable-traversable"
      , "functions"
      , "integers"
      , "lists"
      , "maybe"
      , "orders"
      , "parsing"
      , "partial"
      , "strings"
      ]
    , repo = "https://github.com/hdgarrood/purescript-versions.git"
    , version = "v5.0.1"
    }
