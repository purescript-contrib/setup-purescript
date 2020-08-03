let upstream =
      https://github.com/purescript/package-sets/releases/download/psc-0.13.8-20200724/packages.dhall sha256:bb941d30820a49345a0e88937094d2b9983d939c9fd3a46969b85ce44953d7d9

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
    , repo =
        "https://github.com/hdgarrood/purescript-versions.git"
    , version =
        "v5.0.1"
    }
