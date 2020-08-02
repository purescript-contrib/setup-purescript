# Setup PureScript Action

A GitHub Action which sets up a PureScript toolchain for CI. Contains the following tools:

- The [PureScript compiler](https://github.com/purescript/purescript)
- The [Spago package manager and build tool](https://github.com/purescript/spago)
- The [Zephyr dead code elimination tool](https://github.com/coot/zephyr)

This action is designed to support tools with static binaries. Your PureScript project may also depend on tooling and libraries provided by the NPM ecosystem, in which case you will also want to use the [setup-node](https://github.com/actions/setup-node) action.

> Note: While this action does work, it is currently under development and the API may change. Feel free to experiment using it, but it won't be stable until a v1 release when the PureScript Contributor organization switches to use it.

## Usage

See the [action.yml](action.yml) file for all possible inputs and outputs.

### Basic

Get the latest versions of PureScript, Spago, and Zephyr in the environment:

```yaml
steps:
  - uses: actions/checkout@v2
  - uses: thomashoneyman/setup-purescript@master
  - run: spago build
```

### Use Specific Versions

Use specific versions of any tool by supplying a valid semantic version (only exact versions currently supported):

```yaml
steps:
  - uses: actions/checkout@v2
  - uses: thomashoneyman/setup-purescript@master
    with:
      purescript-version: "0.13.8"
      spago-version: "0.15.3"
      zephyr-version: "0.3.2"
  - run: spago build
```

### Cache Library Dependencies (Coming Soon)

Automatically build and cache library dependencies between workflow runs by supplying a path to a Spago config file:

```yaml
steps:
  - uses: actions/checkout@v2
  - uses: thomashoneyman/setup-purescript@master
    with:
      cache: "spago.dhall"
  - run: spago build
```
