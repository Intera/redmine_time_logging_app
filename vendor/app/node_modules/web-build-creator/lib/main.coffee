nodejs = {}
fs = require "fs"
log = require("./logger").log
deepCopy = require("ncp").ncp
nodejs.path = require "path"
_ = require "underscore"
watch = require "node-watch"
util = require "./utility"

default_config =
  source_dir: ""
  target_dir: "../compiled/"

prepare_config = (arg) ->
  throw "missing configuration object" unless arg
  arg = _.defaults(arg, default_config)
  arg.target_dir = util.ensure_trailing_slash(arg.target_dir)
  arg.source_dir = util.ensure_trailing_slash(arg.source_dir)
  arg

wbc_script = (config) ->
  log "compile script", 1
  util.validate_script_config config
  config.script.forEach (ele) ->
    target_path = config.target_dir + ele.target
    util.ensure_directory_structure nodejs.path.dirname(target_path)
    util.create_file target_path
    path_prefix = ele.path_prefix or ""
    source_paths = util.any_to_array(ele.sources).map (path) ->
      path = config.source_dir + path_prefix + path
      if fs.existsSync path
        path
      else if fs.existsSync path + ".coffee"
        path + ".coffee"
      else path + ".js"
    source_paths.forEach (path) ->
      log "reading " + path
    log "writing #{target_path}"
    util.convert_append_files target_path, source_paths, (content, path) ->
      if path.match /\.coffee$/ then util.compile_coffeescript content else content
    if !config.debug
      log "compressing #{target_path}"
      util.process_file target_path, util.compress_js
    if ele.gzip
      log "creating #{target_path}.gz"
      util.create_gzip_copy target_path
  log "", -1

wbc_style = (config) ->
  log "compile css", 1
  config.style.forEach (ele) ->
    target_path = config.target_dir + ele.target
    log "creating " + target_path
    util.ensure_directory_structure nodejs.path.dirname(target_path)
    util.create_file target_path
    path_prefix = ele.path_prefix or ""
    source_paths = util.any_to_array(ele.sources).map (path) ->
      config.source_dir + path_prefix + path + '.css'
    source_paths.forEach (path) ->
      log "reading " + path
    log "writing #{target_path}"
    util.convert_append_files target_path, source_paths
    if !config.debug
      log "compressing #{target_path}"
      util.process_file target_path, util.compress_css
    if ele.gzip
      log "creating #{target_path}.gz"
      util.create_gzip_copy target_path
  log "", -1

wbc_html = (config) ->
  log "compress_html", 1
  config.html.forEach (ele) ->
    target_path = config.target_dir + ele.target
    util.ensure_directory_structure nodejs.path.dirname(target_path)
    util.create_file target_path
    path_prefix = ele.path_prefix or ""
    source_paths = util.any_to_array(ele.sources).map (path) ->
      path = config.source_dir + path_prefix + path
      if fs.existsSync path
        path
      else if fs.existsSync path + ".coffee"
        path + ".coffee"
      else path + ".js"
    source_paths.forEach (path) ->
      log "reading " + path
    log "writing #{target_path}"
    util.convert_append_files target_path, source_paths, (content, path) ->
      if path.match /\.coffee$/ then util.compile_coffeekup content else content
    if !config.debug
      log "compressing #{target_path}"
      util.process_file target_path, util.compress_html
    if ele.gzip
      log "creating #{target_path}.gz"
      util.create_gzip_copy target_path
  log "", -1

wbc_sync = (config) ->
  log "sync", 1
  config.sync.forEach (config_sync) ->
    if _.isArray config_sync
      source_path = config.source_dir + config_sync[0]
      target_path = config.target_dir + config_sync[1]
    else
      source_path = config.source_dir + config_sync
      target_path = config.target_dir + config_sync
    log "copying #{source_path} -> #{target_path}"
    deepCopy source_path, target_path, ->
  log "", -1

create_build = (config) ->
  try
    config = prepare_config config
    util.ensure_directory_structure config.target_dir
    if config.style then wbc_style config
    if config.html then wbc_html config
    if config.sync then wbc_sync config
    if config.script then wbc_script config
    log "success"
  catch exc
    try
      logger.display_log()
    if exc
      console.log "#{exc.message}" + " line #{5}, column #{29}"
      console.log "Stack trace:\n#{exc.stack}"
    else
      console.log exc

watch_create_build = (path, config, filename_filter) ->
  create_build(config)
  console.log("\nnow waiting for new changes in \"source\"...")
  watch path, (filename) ->
    if filename_filter and filename_filter filename then create_build config
    else create_build config

exports.create_build = create_build
exports.watch_create_build = watch_create_build
exports.watch = watch
