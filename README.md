# Setup PureScript Action

[![Integration](https://github.com/thomashoneyman/setup-purescript/workflows/Integration/badge.svg?branch=main)](https://github.com/thomashoneyman/setup-purescript/actions?query=workflow%3AIntegration+branch%3Amain)
[![Sync Versions](https://github.com/thomashoneyman/setup-purescript/workflows/Sync%20Versions/badge.svg?branch=main)](https://github.com/thomashoneyman/setup-purescript/actions?query=workflow%3A"Sync+Versions"+branch%3Amain)

A GitHub Action which sets up a PureScript toolchain for CI. Contains the following tools by default:

- The [PureScript compiler](https://github.com/purescript/purescript)
- The [Spago package manager and build tool](https://github.com/purescript/spago)
  - Use the `unstable` version for spago-next; otherwise, setup-purescript provides [`spago-legacy`](https://github.com/purescript/spago-legacy); see [issue 37](https://github.com/purescript-contrib/setup-purescript/issues/37)
- The [`psa` error reporting frontend for the compiler](https://github.com/natefaubion/purescript-psa)

You can also optionally include the following tools:

- The [`purs-tidy` code formatter](https://github.com/natefaubion/purescript-tidy)
- The [Zephyr dead code elimination tool](https://github.com/coot/zephyr)

This action is designed to support PureScript tools. Your PureScript project may also depend on tooling and libraries provided by the NPM ecosystem, in which case you will also want to use the [setup-node](https://github.com/actions/setup-node) action.

## Usage

See the [action.yml](action.yml) file for all possible inputs and outputs.

### Basic

Use the PureScript toolchain with the latest versions of PureScript and Spago:

```yaml
steps:
  - uses: actions/checkout@v2
  - uses: purescript-contrib/setup-purescript@main
  - run: spago build
```

Other tools are not enabled by default, but you can enable them by specifying their version.

### Specify Versions

Each tool can accept one of the following:
- a semantic version (only exact versions currently supported)
- the string `"latest"`, which represents the latest version that uses major, minor, and patch, but will omit versions using pre-release identifiers or build metadata
- the string `"unstable"`, which represents the latest version no matter what it is (i.e. pre-release identifiers and build metadata are not considered).

Tools that are not installed by default must be specified this way to be included in the toolchain.

```yaml
steps:
  - uses: actions/checkout@v2
  - uses: purescript-contrib/setup-purescript@main
    with:
      purescript: "0.14.0"
      psa: "0.8.2"
      spago: "latest"
      purs-tidy: "latest"
      zephyr: "0.3.2"
  - run: spago build
```

## Full Example Workflow

This workflow is a useful starting point for new projects and libraries. You can add a `.yml` file with the contents below to the `.github/workflows` directory in your project (for example: `.github/workflows/ci.yml`).

```yml
name: CI

on: push

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - uses: purescript-contrib/setup-purescript@main

      - name: Cache PureScript dependencies
        uses: actions/cache@v2
        # This cache uses the .dhall files to know when it should reinstall
        # and rebuild packages. It caches both the installed packages from
        # the `.spago` directory and compilation artifacts from the `output`
        # directory. When restored the compiler will rebuild any files that
        # have changed. If you do not want to cache compiled output, remove
        # the `output` path.
        with:
          key: ${{ runner.os }}-spago-${{ hashFiles('**/*.dhall') }}
          path: |
            .spago
            output

      - run: spago build

      - run: spago test --no-install
```

## Development

Enter a development shell with necessary tools installed:

```sh
nix-shell
```

If you need any additional tools not included in this Nix expression or available via NPM, please feel free to add them via [easy-purescript-nix](https://github.com/justinwoo/easy-purescript-nix).

Next, install NPM dependencies:

```sh
npm install
```

GitHub Actions uses the `action.yml` file to define the action and the `dist/index.js` file to execute it. After making any changes to the source code, make sure those changes are visible by running:

```sh
npm run build
```

This will bundle and minify the source code so it is available to the end user.

## Used By

These libraries and applications are examples of `setup-purescript` in action:

- [halogen](https://github.com/purescript-halogen/purescript-halogen/blob/master/.github/workflows/ci.yml)
- [halogen-realworld](https://github.com/thomashoneyman/purescript-halogen-realworld/blob/main/.github/workflows/ci.yml)
- [halogen-formless](https://github.com/thomashoneyman/purescript-halogen-formless/blob/main/.github/workflows/ci.yml)
- [halogen-hooks](https://github.com/thomashoneyman/purescript-halogen-hooks/blob/main/.github/workflows/ci.yml)
- [slug](https://github.com/thomashoneyman/purescript-slug/blob/main/.github/workflows/ci.yml)
- ...add your package here!
