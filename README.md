# Setup PureScript Action

[![Integration](https://github.com/thomashoneyman/setup-purescript/workflows/Integration/badge.svg?branch=main)](https://github.com/thomashoneyman/setup-purescript/actions?query=workflow%3AIntegration+branch%3Amain) [![Sync Versions](https://github.com/thomashoneyman/setup-purescript/workflows/Sync%20Versions/badge.svg?branch=main)](https://github.com/thomashoneyman/setup-purescript/actions?query=workflow%3A"Sync+Versions"+branch%3Amain)

A GitHub Action which sets up a PureScript toolchain for CI. Contains the following tools by default:

- The [PureScript compiler](https://github.com/purescript/purescript)
- The [Spago package manager and build tool](https://github.com/purescript/spago)

You can also optionally include the following tools:

- The [Zephyr dead code elimination tool](https://github.com/coot/zephyr)
- The [Purty source code formatter](https://gitlab.com/joneshf/purty)

This action is designed to support tools with static binaries. Your PureScript project may also depend on tooling and libraries provided by the NPM ecosystem, in which case you will also want to use the [setup-node](https://github.com/actions/setup-node) action.

> Note: While this action does work, it is currently under development and the API may change. Feel free to experiment using it, but it won't be stable until a v1 release when the PureScript Contributor organization switches to use it.

## Usage

See the [action.yml](action.yml) file for all possible inputs and outputs.

### Basic

Use the PureScript toolchain with the latest versions of PureScript and Spago:

```yaml
steps:
  - uses: actions/checkout@v2
  - uses: thomashoneyman/setup-purescript@main
  - run: spago build
```

Other tools are not enabled by default, but you can enable them by specifying their version.

### Specify Versions

Each tool can accept a semantic version (only exact versions currently supported) or the string `"latest"`. Tools that are not installed by default must be specified this way to be included in the toolchain.

```yaml
steps:
  - uses: actions/checkout@v2
  - uses: thomashoneyman/setup-purescript@main
    with:
      purescript: "0.13.8"
      spago: "0.15.3"
      purty: "latest"
      zephyr: "0.3.2"
  - run: spago build
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
npm run package
```

This will bundle and minify the source code so it is available to the end user.
