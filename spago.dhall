{ name = "setup-purescript"
, dependencies =
  [ "aff"
  , "aff-retry"
  , "affjax"
  , "argonaut-codecs"
  , "argonaut-core"
  , "arrays"
  , "bifunctors"
  , "control"
  , "effect"
  , "either"
  , "enums"
  , "exceptions"
  , "foldable-traversable"
  , "foreign-object"
  , "github-actions-toolkit"
  , "integers"
  , "lists"
  , "math"
  , "maybe"
  , "newtype"
  , "node-buffer"
  , "node-fs"
  , "node-fs-aff"
  , "node-path"
  , "node-process"
  , "ordered-collections"
  , "parsing"
  , "partial"
  , "prelude"
  , "refs"
  , "strings"
  , "tailrec"
  , "transformers"
  , "tuples"
  , "versions"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs" ]
}
