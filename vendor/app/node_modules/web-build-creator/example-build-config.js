var wbc = require("web-build-creator")

var websiteBuild = {
	target_dir: "../website",
	// if debug is true then the js/html/css files are not compressed
	debug: false,
	script: [
		{
			target: "js/my-target-file",
			sources: ["file-1", "file-2", "file-3"],
			gzip: true
		},
		{
			target: "js/my-target-file",
			sources: "file-4"
		}
	],
	style: [
		{
			target: "css/file-5",
			sources: [
				"../lib/css/file-6",
				"file-7"
			]
		}
	],
	html: [
		{
			target: "index",
			sources: "index-website"
		}
	],
	sync: [
		"img",
		["content-source.html", "test/html/content.html"]
	]
}

wbc.create_build(websiteBuild)
