const core = require("@actions/core");
const tc = require("@actions/tool-cache");
const semver = require("semver");

const PureScript = "PureScript";
const Spago = "Spago";

const toolName = (tool) => {
  if (tool === PureScript) return "purs";
  if (tool === Spago) return "spago";
};

const toolRepository = (tool) => {
  if (tool === PureScript) return "purescript/purescript";
  if (tool === Spago) return "purescript/spago";
};

const toolVersionKey = (tool) => {
  if (tool === PureScript) return "purescript-version";
  if (tool === Spago) return "spago-version";
};

const toolLatestTag = (tool) => {
  // TODO
  // Get the latest tag automatically:
  // TAG=$(basename $(curl --location --silent --output /dev/null -w %{url_effective} https://github.com/purescript/purescript/releases/latest))
  if (tool === PureScript) return "0.13.8";
  if (tool === Spago) return "0.15.3";
};

const toolVersion = (tool) => {
  const key = toolVersionKey(tool);
  const input = core.getInput(tool);
  if (input) {
    if (semver.valid(input)) {
      return input;
    } else {
      core.setFailed(`${input} is not valid for ${key}.`);
    }
  } else {
    return toolLatestTag(tool);
  }
};

const Windows = "Windows";
const Mac = "Mac";
const Linux = "Linux";

const parsePlatform = (platform) => {
  if (platform === "win32") return Windows;
  if (platform === "darwin") return Mac;
  return Linux;
};

const tarballName = (tool, platform) => {
  if (tool === PureScript) {
    if (platform === Windows) return "win64";
    if (platform === Mac) return "macos";
    if (platform === Linux) return "linux64";
  } else if (tool === Spago) {
    if (platform === Windows) return "windows";
    if (platform === Mac) return "osx";
    if (platform === Linux) return "linux";
  }
};

const downloadTool = async (tool) => {
  const version = toolVersion(tool);
  const name = toolName(tool);

  // If the tool has previously been downloaded at the provided version, then we
  // can simply add it to the PATH
  const cached = tc.find(name, version);
  if (cached) {
    core.addPath(cached);
    console.log(`Found cached version of ${name}, adding to PATH`);
    return;
  }

  const platform = parsePlatform(process.platform);
  const tarball = tarballName(tool, platform);
  const repo = toolRepository(tool);

  const downloadPath = await tc.downloadTool(
    `https://github.com/${repo}/releases/download/${version}/${tarball}.tar.gz`
  );

  const extracted = await tc.extractTar(downloadPath);

  switch (tool) {
    case PureScript:
      const purescriptPath = await tc.cacheDir(extracted, name, version);
      core.addPath(purescriptPath);
      return;

    case Spago:
      let spagoPath = await tc.cacheFile(extracted, name, name, version);
      core.addPath(spagoPath);
      return;
  }
};

const run = async () => {
  await downloadTool(PureScript);
  await downloadTool(Spago);
};

run();
