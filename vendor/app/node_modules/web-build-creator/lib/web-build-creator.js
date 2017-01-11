// this file is for being able to use coffee-script
require("coffee-script/register")
main = require("./main.coffee")
exports.create_build = main.create_build
exports.watch_create_build = main.watch_create_build
exports.watch = main.watch
