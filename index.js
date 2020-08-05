"use strict";

var Main = require("./output/index");
var versions = require("./dist/versions.json");

Main.main(versions)();
