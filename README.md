# Setup PureScript Action

[![Integration](https://github.com/thomashoneyman/setup-purescript/workflows/Integration/badge.svg?branch=main)](https://github.com/thomashoneyman/setup-purescript/actions?query=workflow%3AIntegration+branch%3Amain)
[![Sync Versions](https://github.com/thomashoneyman/setup-purescript/workflows/Sync%20Versions/badge.svg?branch=main)](https://github.com/thomashoneyman/setup-purescript/actions?query=workflow%3A"Sync+Versions"+branch%3Amain)

A GitHub Action which sets up a PureScript toolchain for CI. Contains the following tools by default:

- The [PureScript compiler](https://github.com/purescript/purescript)
- The [Spago package manager and build tool](https://github.com/purescript/spago)
  - `latest` currently selects Spago 1.x. Pin an exact legacy version, such as `0.21.0`, for projects using Dhall configuration.
- The [`psa` error reporting frontend for the compiler](https://github.com/natefaubion/purescript-psa)

You can also optionally include the following tools:

- The [`purs-tidy` code formatter](https://github.com/natefaubion/purescript-tidy)
- The [Zephyr dead code elimination tool](https://github.com/coot/zephyr)

The action itself runs on GitHub's Node24 action runtime. This does **not** select the Node executable on your workflow's `PATH`: installed npm tools use that separate Node installation. Spago 1.0.4 requires Node >=22.5.0. Use [setup-node](https://github.com/actions/setup-node) with Node24 **before** this action, as shown below.

Self-hosted runners need Actions Runner v2.327.1 or newer for the Node24 action runtime. Node24 does not support macOS 13.4 or earlier, or officially support ARM32. The compiler and legacy-tool downloads still use the existing x86-64 tarballs; this runtime update does not add native ARM64 tool installation. Integration tests cover Linux, Intel macOS, and Windows.

## Usage

See the [action.yml](action.yml) file for all possible inputs and outputs.

### Basic

Use the PureScript toolchain with the latest versions of PureScript and Spago:

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: actions/setup-node@v7
    with:
      node-version: "24"
  - uses: purescript-contrib/setup-purescript@main
  - run: spago build
```

This installs PureScript, Spago, and PSA. Only purs-tidy and Zephyr are opt-in.

### Specify Versions

Each tool can accept one of the following:
- a semantic version (only exact versions currently supported)
- `"latest"`, which selects the tool's recorded stable version
- `"unstable"`, which selects the tool's recorded unstable version
- `""`, which skips installation of that tool, including tools enabled by default.

Aliases are resolved from [`dist/versions-v2.json`](dist/versions-v2.json) on `main`, even when you pin an action release. For Spago and purs-tidy, the version updater reads npm's `latest` and `next` dist-tags, falling back to `latest` when `next` is absent. `unstable` does not necessarily mean a newer version: Spago's recorded unstable version is currently 0.93.x, while its latest version is 1.x. Use exact tool versions for reproducible selection.

Tools that are not installed by default must be specified this way to be included in the toolchain.

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: actions/setup-node@v7
    with:
      node-version: "24"
  - uses: purescript-contrib/setup-purescript@main
    with:
      purescript: "0.15.15"
      psa: ""
      spago: "1.0.4"
      purs-tidy: "latest"
  - run: spago build
```

Omitting `psa` still installs it; only the explicit empty string above disables it. Legacy Spago and PSA pins remain supported, for example `spago: "0.21.0"` and `psa: "0.8.2"`. Bower/Pulp consumers can set `spago: ""` if they do not need Spago, and should install Bower/Pulp separately.

## Full Example Workflow

This workflow is a useful starting point for new projects and libraries. You can add a `.yml` file with the contents below to the `.github/workflows` directory in your project (for example: `.github/workflows/ci.yml`).

```yml
name: CI

on: push

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-node@v7
        with:
          node-version: "24"

      - uses: purescript-contrib/setup-purescript@main

      - name: Cache PureScript dependencies
        uses: actions/cache@v6
        # For registry-based Spago projects. Legacy projects should hash
        # their *.dhall files instead.
        with:
          key: ${{ runner.os }}-spago-${{ hashFiles('**/spago.yaml', '**/spago.lock') }}
          path: |
            .spago
            output

      - run: spago build

      - run: spago test
```

## Development

Use Node24 and the pinned build tools used by Integration:

```sh
npm install --global purescript@0.15.15 spago@1.0.4 purs-tidy@0.11.1
npm ci
npm run check
npm run build
```

`npm run build` compiles and checks dependencies; it does not regenerate the action. After source changes, regenerate the checked-in bundles:

```sh
npm run bundle
```

The small `index.js` and `update.js` entry points import freshly compiled code from `output/index.js`. Bundling produces `dist/index.js` (the action) and `dist/update.js` (the version updater). Commit generated bundle changes together with their source. Integration checks that rebuilding produces the committed contents and that two consecutive builds are identical.

Integration also installs default, latest, pinned modern, and pinned legacy toolchains on all three operating systems, checks PSA opt-out and Windows npm shims, and builds/runs small registry and Dhall consumer fixtures. It has read-only repository permissions and never runs the version updater. **Sync Versions is separate:** it writes both shared version manifests and commits/pushes them. Do not run or enable it merely to validate a code change.

## Used By

These libraries and applications are examples of `setup-purescript` in action:

- [halogen](https://github.com/purescript-halogen/purescript-halogen/blob/master/.github/workflows/ci.yml)
- [halogen-realworld](https://github.com/thomashoneyman/purescript-halogen-realworld/blob/main/.github/workflows/ci.yml)
- [halogen-formless](https://github.com/thomashoneyman/purescript-halogen-formless/blob/main/.github/workflows/ci.yml)
- [halogen-hooks](https://github.com/thomashoneyman/purescript-halogen-hooks/blob/main/.github/workflows/ci.yml)
- [slug](https://github.com/thomashoneyman/purescript-slug/blob/main/.github/workflows/ci.yml)
- ...add your package here!
