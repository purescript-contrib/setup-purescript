import * as core from "@actions/core";
import * as tc from "@actions/tool-cache";
import * as semver from "semver";
import * as path from "path";
import * as axios from "axios";

const PureScript = "PureScript";
const Spago = "Spago";
const Zephyr = "Zephyr";

const toolName = (tool) => {
  if (tool === PureScript) return "purs";
  if (tool === Spago) return "spago";
  if (tool === Zephyr) return "zephyr";
};

const toolRepository = (tool) => {
  if (tool === PureScript) return "purescript/purescript";
  if (tool === Spago) return "purescript/spago";
  if (tool === Zephyr) return "coot/zephyr";
};

const toolVersionKey = (tool) => {
  if (tool === PureScript) return "purescript-version";
  if (tool === Spago) return "spago-version";
  if (tool === Zephyr) return "zephyr-version";
};

const toolVersion = async (tool) => {
  const key = toolVersionKey(tool);
  const input = core.getInput(key);

  if (input == "latest") {
    core.info(`Fetching latest tag for ${tool}`);
    const repo = toolRepository(tool);
    const url = `https://api.github.com/repos/${repo}/releases/latest`;

    try {
      const response = await axios.get(url);
      return response.data.tag_name;
    } catch (err) {
      core.setFailed(`Failed to get latest tag: ${err}`);
    }
  } else if (semver.valid(input)) {
    if (tool === PureScript || tool === Zephyr) return `v${input}`;
    return input;
  } else {
    core.setFailed(`${input} is not valid for ${key}.`);
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
  } else if (tool === Zephyr) {
    if (platform === Windows) return "Windows";
    if (platform === Mac) return "macOS";
    if (platform === Linux) return "Linux";
  }
};

const downloadTool = async (tool) => {
  const version = await toolVersion(tool);
  const name = toolName(tool);

  // If the tool has previously been downloaded at the provided version, then we
  // can simply add it to the PATH.
  const cached = tc.find(name, version);
  if (cached) {
    core.info(
      `Found cached version of ${name} at version ${version}, adding to PATH.`
    );
    core.addPath(cached);
    return;
  }

  core.info(
    `Did not find cached version of ${name} at version ${version}, fetching.`
  );

  const platform = parsePlatform(process.platform);
  const tarball = tarballName(tool, platform);
  const repo = toolRepository(tool);
  const url = `https://github.com/${repo}/releases/download/${version}/${tarball}.tar.gz`;

  const downloadPath = await tc.downloadTool(url);
  let extracted = await tc.extractTar(downloadPath);

  if (tool === PureScript) {
    extracted = path.join(extracted, "purescript");
  } else if (tool === Zephyr) {
    extracted = path.join(extracted, "zephyr");
  }

  const cachedPath = await tc.cacheDir(extracted, name, version);
  core.info(`Cached path ${cachedPath}.`);
  core.addPath(cachedPath);
  return;
};

const run = async () => {
  await downloadTool(PureScript);
  await downloadTool(Spago);
  await downloadTool(Zephyr);
};

run();
