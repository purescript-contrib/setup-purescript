const core = require("@actions/core");

exports.addPath = (path) => () => core.addPath(path);

exports.debug = (msg) => () => core.debug(msg);

exports.error = (msg) => () => core.error(msg);

exports.exportVariable = ({ key, value }) => () =>
  core.exportVariable(key, value);

exports.getInputImpl = (name) => () => {
  const input = core.getInput(name);
  if (input === "") return null;
  return input;
};

exports.info = (msg) => () => core.info(msg);

exports.setFailed = (msg) => () => core.setFailed(msg);

exports.warning = (msg) => () => core.warning(msg);
