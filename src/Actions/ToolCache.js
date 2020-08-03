const tc = require("@actions/tool-cache");

exports.cacheDirImpl = tc.cacheDir;

exports.cacheFileImpl = tc.cacheFile;

exports.downloadToolImpl = tc.downloadTool;

exports.extractTarImpl = tc.extractTar;

// We manually make this function an effect, as it doesn't return a Promise and
// can throw exceptions.
exports.findImpl = (toolName) => (versionSpec) => () => {
  return tc.find(toolName, versionSpec);
};
