# Features

- Javascript, CSS and HTML compression
- File and directory tree synchronisation with renaming
- File and directory watching with automatic compile
- File merging
- Gzip compression
- Coffeescript\Coffeekup support
- Inheritable configuration

# Dependencies
- nodejs

all other dependencies are included.

# Installation
    npm install web-build-creator

## Alternative
    git clone https://github.com/Intera/web-build-creator.git
    npm install path-to-cloned-directory

# Usage
* Create a Javascript file - this can be executable
* Define a configuration object
* Load the wbc module
* Call wbc.create_build(config)
* Or call wbc.watch_create_build(path, config)

## Configuration
[Example](https://raw.githubusercontent.com/Intera/web-build-creator/master/example-build-config.js)

The configuration object is a javascript object

``{}``

and can have the following keys

- debug
- html
- script
- source_dir
- style
- sync
- target_dir

Following are descriptions for the key associations.

### script
```javascript
script: [
	{
    target: target,
    path_prefix: string,
		sources: sources,
		gzip: boolean
	},
  ...
]
```

- Sources can be a single path or an array of paths, with or without filename suffixes. Example: "js/test" stands for "js/test.js"
- The value of path_prefix is prepended to all source paths
- Target is one path, relative to the target_dir
- Gzip, if true, creates a gzip compressed copy of the file with the same name and a .gz suffix. Can also be omitted or false

### style
```javascript
style: [
	{
    target: target,
    path_prefix: string,
		sources: sources,
		gzip: boolean
	},
  ...
]
```

- Sources can be a single path or an array of paths, with or without filename suffixes. example: "css/test" stands for "css/test.css".
- The value of path_prefix is prepended to all source paths
- Target is one path, relative to the target_dir
- Gzip, if true, creates a gzip compressed copy of the file with the same name and a .gz suffix. Can also be omitted or false

### html
```javascript
html: [
	{
    target: target,
    path_prefix: string,
		sources: sources,
		gzip: boolean
	},
  ...
]
```

- Sources can be a single path or an array of paths, with or without filename suffixes. Example: "html/test" stands for "html/test.html".
- The value of path_prefix is prepended to all source paths
- Target is one path, relative to the target_dir
- Gzip, if true, creates a gzip compressed copy of the file with the same name and a .gz suffix. Can also be omitted or false

### sync
```javascript
sync: [
  path,
	[source-path, target-path],
	...
]
```

path can be a single path relative to source_dir, or a two element array with paths where the first path is the source path and the second is the target path.
Directory structures are created automatically. Existing files are overwritten and never deleted.

### other keys
|key|description|default value|
----|----|----
|debug|if debug is true the js/html/css files are not compressed|false|
|source_dir|path prefix for source files|""|
|target_dir|path prefix for compiled target files|"../compiled/"|

## File watching
    require("web-build-creator").watch_create_build("source", build-config)
stop with ctrl+c

## Caveats
If you compress HTML, you must use semicolons for inline Javascript, and line-comments can only be used for the last line of a ``<script>`` tag.

# Developer infos
The included dependencies as node modules are:

- clean-css
- coffee-script
- html-minifier
- ncp
- uglifyjs
- underscore

It is written in coffeescript for the most part.

# Possible enhancements
- lesscss support

# Similar projects
[cake-flour](https://github.com/ricardobeat/cake-flour)