# Setup PureScript Action

A GitHub Action which sets up a PureScript toolchain for CI. Contains the following tools:

- The [PureScript compiler](https://github.com/purescript/purescript)
- The [Spago package manager and build tool](https://github.com/purescript/spago)

## Usage

See the [action.yml](action.yml) file for all possible inputs and outputs.

### Basic

Get the latest versions of PureScript and Spago in the environment:

```yaml
steps:
  - uses: actions/checkout@v2
  - uses: thomashoneyman/setup-purescript@master
  - run: spago build
```

### Use Specific Versions

Use specific versions of PureScript and/or Spago by supplying a valid tag in their respective GitHub repositories:

```yaml
steps:
  - uses: actions/checkout@v2
  - uses: thomashoneyman/setup-purescript@master
    with:
      purescript-version: "0.13.8"
      spago-version: "0.15.3"
  - run: spago build
```
