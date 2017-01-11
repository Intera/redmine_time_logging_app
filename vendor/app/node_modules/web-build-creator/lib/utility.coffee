fs = require "fs"
$path = require "path"
uglify_js = require "uglify-js"
clean_css = require "clean-css"
htmlMinifier = require("html-minifier").minify
zlib = require "zlib"
_ = require "underscore"
coffee = require "coffee-script"
try
  coffeekup = require "coffeekup"
try
  less = require "less"

any_to_array = (a) -> # string -> string
  if _.isArray(a) then a else [a]

compress_js = (s) -> # string -> string
  uglify_js.minify(s, fromString: true).code

compress_css = (s) -> # string -> string
  c = new clean_css
    keepSpecialComments: 0
    removeEmpty: true
  c.minify s

compile_coffeescript = (s) ->
  coffee.compile s, bare: true

compile_coffeekup = (s) ->
  if coffeekup
    coffeekup.render s
  else throw new Error "coffeekup is not installed. npm install coffeekup"

compile_less = (s) ->
  # this is asynchronous and can not be integrated because of this yet
  if less
    parser = new less.Parser
    parser.parse s, (error, tree) ->
      if error then console.error(error) else tree.toCSS()
  else throw new Error "less is not installed. npm install less"

compress_html = (s) ->
  htmlMinifier s,
    removeComments: true
    collapseWhitespace: true

ensure_directory_structure = (path) ->
  fs.existsSync(path) or (ensure_directory_structure($path.dirname(path)) and fs.mkdirSync(path))

string_suffix = (str, suffix) ->
  str.lastIndexOf(suffix) is (str.length - suffix.length)

ensure_trailing_slash = (str) ->
  if string_suffix(str, "/") then str else str + "/"

String::repeat = (num) ->
  new Array(num + 1).join this

create_file = (path) ->
  fs.closeSync fs.openSync(path, "w")

process_file = (path, proc) ->
  fs.writeFileSync path, proc fs.readFileSync path, "utf8"

convert_append_files = (target_path, paths, convert) ->
  if !fs.existsSync target_path then create_file target_path
  if !convert then convert = (arg) -> arg
  paths.forEach (path) ->
    fileContent = fs.readFileSync path, "utf8"
    # remove utf-8 byte-order-mark
    fileContent = fileContent.substring(1) if fileContent.charCodeAt(0) is 65279
    fs.appendFileSync target_path, convert(fileContent, path)

add_suffix_func = (suffix) ->
  (str) ->
    (if string_suffix(str, suffix) then str else str + suffix)

create_gzip_copy = (path) ->
  gzip = zlib.createGzip(level: zlib.Z_BEST_COMPRESSION)
  inp = fs.createReadStream(path)
  out = fs.createWriteStream(path + ".gz")
  inp.pipe(gzip).pipe out

script_config_fileset_p = (arg) ->
  if not (arg.target and arg.sources)
    throw "missing option \"target\" or \"source\""

validate_script_config = (arg) ->
  _.isArray arg and arg.length > 0 and _.isObject arg[0] and script_config_fileset_p arg[0]

exports.any_to_array = any_to_array
exports.validate_script_config = validate_script_config
exports.create_gzip_copy = create_gzip_copy
exports.add_suffix_func = add_suffix_func
exports.create_file = create_file
exports.convert_append_files = convert_append_files
exports.ensure_trailing_slash = ensure_trailing_slash
exports.string_suffix = string_suffix
exports.ensure_directory_structure = ensure_directory_structure
exports.compress_js = compress_js
exports.compress_css = compress_css
exports.compress_html = compress_html
exports.process_file = process_file
exports.compile_coffeescript = compile_coffeescript
exports.compile_coffeekup = compile_coffeekup