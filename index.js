"use strict";

var Main = require("./output/index");
var versions = require("./dist/versions.json");
console.log(versions);

Main.main(versions)();
