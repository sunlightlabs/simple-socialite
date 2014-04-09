fs = require 'fs'
{exec} = require 'child_process'

Q = null
jsp = null
pro = null
_ = null
glob = null
copysync = null
wrench = null

settings = require('./settings.coffee').settings
extensions = []
EXTENSIONS_CACHE_PATH = './.tmp/extensions'


option '-e', '--extensions [EXT]', 'A space-delimited list of Socialite extensions to compile into the build'

task 'build', 'Run the whole build chain, writing output to /build', (options) ->
  verify -> clean -> install_components -> verify_extensions options, -> compile -> apply_settings -> pack -> minify -> clean_sources -> finish('Built files to ./build.\n', true)

task 'verify', 'Checks to be sure that npm deps are installed and settings are valid', ->
  verify()

task 'clean', 'Deletes the /build folder', ->
  verify -> clean -> finish('Build folder cleaned.')

task 'clean_sources', 'Deletes the extension source cache', ->
  verify -> clean_sources -> finish('Source cache cleaned.')

task 'install_components', 'Installs any dependencies declared in bower.json', ->
  verify -> install_components -> finish('Bower dependencies installed.')

task 'verify_extensions', 'Ensure listed extensions are gathered from sources listed in settings', (options) ->
  verify -> install_extensions options, -> finish('Extensions installed.')

task 'compile', 'Compile the coffeescript source', ->
  verify -> compile -> finish('Simple-socialite compilation complete.')

task 'apply_settings', 'Fills in settings blocks in js from settings file', ->
  verify -> apply_settings -> finish('Settings applied.')

task 'pack', 'Combine extension files with socialite', ->
  verify -> pack -> finish('Files concatenated.')

task 'minify', 'Compress output js into a single .min.js file', ->
  verify -> minify -> finish('Concatenated scripts minified.')


apply_settings = (callback) ->
  file = './build/simple-socialite.js'
  js = fs.readFileSync(file).toString().replace(/\{% settings\.([A-Z_]+) %\}/g, (match, capture) -> settings[capture])
  fs.writeFileSync file, js
  callback?()

clean = (callback) ->
  wrench.rmdirSyncRecursive('./build', true)
  wrench.rmdirSyncRecursive('./components', true)
  clean_sources -> callback?()

clean_sources = (callback) ->
  wrench.rmdirSyncRecursive('./.tmp', true)
  callback?()

compile = (callback) ->
  Q.when(_handle_sysio(exec('coffee -co build src'), 'Coffee'))
  .done( ->
    callback?()
  )

finish = (message, callback) ->
  console.log "#{message}"
  callback?()

install_components = (callback) ->
  Q.when(_handle_sysio(exec('bower install'), 'Bower'))
  .done( ->
    callback?()
  )

minify = (callback) ->
  infiles = "./build/*.js"
  paths = glob.sync(infiles)
  zipjobs = []
  for infile in paths
    do (infile) ->
      outfile = infile.replace(/\.js$/, '.min.js')
      js = fs.readFileSync(infile).toString()
      ast = jsp.parse(js)
      ast = pro.ast_mangle(ast)
      ast = pro.ast_squeeze(ast)
      fs.writeFileSync outfile, pro.gen_code(ast)
      zipjobs.push(_handle_sysio(exec("gzip -c #{infile} > #{infile}.gz")))
      zipjobs.push(_handle_sysio(exec("gzip -c #{infile.replace('.js', '.min.js')} > #{infile.replace('.js', '.min.js')}.gz")))
  Q.when(zipjobs...)
    .done( ->
      callback?()
  )

pack = (callback) ->
  js = fs.readFileSync("./bower_components/socialite/socialite.js").toString() + "\n"
  paths = glob.sync("#{EXTENSIONS_CACHE_PATH}/*.js")
  for file in paths
    do (file) ->
      js += fs.readFileSync(file).toString() + "\n"

  js += fs.readFileSync("./build/simple-socialite.js").toString() + "\n"
  fs.writeFileSync("./build/simple-socialite-pack.js", js)
  callback?()

verify = (callback) ->
  settings.ICON_BASE_URL? or throw "No settings file found. Run `cp settings.coffee.example settings.coffee` and add settings first."
  try
    Q = require 'Q'
    jsp = require("uglify-js").parser
    pro = require("uglify-js").uglify
    wrench = require 'wrench'
    glob = require 'glob'
    copysync = require 'copysync'
    _ = require 'underscore'
    _.str = require 'underscore.string'
    _.mixin(_.str.exports())
  catch e
    throw "Please run 'npm install' before continuing. (caught #{e})"
  callback?()

verify_extensions = (options, callback) ->
  exts = options.extensions.split(' ')
  resolved_exts = []
  extension_paths = []
  promises = []

  _local_mkdir_p(EXTENSIONS_CACHE_PATH)

  for path in settings.EXTENSIONS_PATHS
    extension_paths = extension_paths.concat(glob.sync(path))

  for ext in exts
    do (ext) ->
      extension_path = _.filter(extension_paths, (pth) ->
        pth.match(new RegExp("socialite.#{ext}.js")))

      if extension_path.length
        filename = extension_path[0]
        console.log "Found #{ext} at #{filename}."
        copysync filename, "#{EXTENSIONS_CACHE_PATH}"
        resolved_exts.push ext
  diff = _.difference(exts,resolved_exts)
  if diff.length
    throw "Unable to resolve extension(s) #{diff.join(', ')} in any sources!"
  callback?()

_local_mkdir_p = (path) ->
  mkdir_path = '.'
  for part in path.split('/')
    do (part) ->
      mkdir_path += "/#{part}"
      try
        fs.mkdirSync(mkdir_path)
      catch e
        #pass

_handle_sysio = (proc, name) ->
  dfd = Q.defer()

  proc.stderr.on 'data', (data) ->
    process.stderr.write data.toString()
  proc.stdout.on 'data', (data) ->
    console.log data.toString()
  proc.on 'exit', (code) ->
    dfd.reject("'#{name}' exited with error code: #{code}") unless code is 0
    dfd.resolve()
  dfd.promise
