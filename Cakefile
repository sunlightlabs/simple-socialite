fs = require 'fs'
{print} = require 'util'
{exec} = require 'child_process'

Q = null
jsp = null
pro = null
_ = null
ghdl = null
glob = null
copysync = null
wrench = null

settings = require('./settings.coffee').settings
extensions = []


option '-e', '--extensions [EXT]', 'A space-delimited list of Socialite extensions to compile into the build'

task 'build', 'Run the whole build chain, writing output to /build', (options) ->
  verify -> clean -> install_components -> install_socialite -> install_extensions options, -> compile -> apply_settings -> pack -> minify -> finish('Built files to ./build.\n', true)

task 'verify', 'Checks to be sure that npm deps are installed and settings are valid', ->
  verify()

task 'clean', 'Deletes the /build folder', ->
  verify -> clean -> finish('Build folder cleaned.')

task 'clean_sources', 'Deletes the extension source cache', ->
  verify -> clean_sources -> finish('Source cache cleaned.')

task 'install_components', 'Installs any dependencies declared in component.json', ->
  verify -> install_components -> finish('Bower dependencies installed.')

task 'install_socialite', 'Grab socialite from github and put it in the correct place', ->
  verify -> install_socialite -> finish("Socialite installed from #{settings.SOCIALITE_SOURCE.split('#')[0]}.")

task 'install_extensions', 'Ensure listed extensions are gathered from sources listed in settings', (options) ->
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
  unless settings.EXTENSIONS_PATH.charAt(0) == '.'
    throw 'EXTENSIONS_PATH is outside this directory! Refusing to rm -rf wherever it is.'
  wrench.rmdirSyncRecursive(settings.EXTENSIONS_PATH, true)
  callback?()

compile = (callback) ->
  Q.when(_handle_sysio(exec('coffee -co build src'), 'Coffee'))
  .done( ->
    callback?()
  )

finish = (message, callback) ->
  print "#{message}\n"
  callback?()

install_components = (callback) ->
  Q.when(_handle_sysio(exec('bower install'), 'Bower'))
  .done( ->
    callback?()
  )

install_extensions = (options, callback) ->
  exts = options.extensions.split(' ')
  resolved_exts = []
  sources = _.filter(settings.EXTENSIONS_SOURCES, (src)->
    # require source to be a github repo
    !! src.match(/\:\/\/github\.com\/.+\.git/)?)
  path = _.rtrim(settings.EXTENSIONS_PATH, '/')
  cache_path = "#{path}/.cache"
  tmppath = "./tmp"
  promises = []

  # gather all sources and download their repos to a temporary path
  # then copy any extensions to an extensions cache
  for source in sources
    do (source) ->
      outer = Q.defer()
      [repo, repopath] = source.split('#')
      reponame = _.chain(repo.split('/').slice(-2).join('/')).rtrim('.git').value()
      repopath = _.trim(repopath, '/')
      tmpextpath = "./tmp/#{reponame}/#{repopath}"
      copyfiles = []

      try
        fs.mkdirSync('./tmp')
      catch e
        #pass

      try
        fs.mkdirSync("./tmp/#{reponame.split('/')[0]}")
      catch e
        #pass

      Q.when(_handle_gh_download(repo, "./tmp/#{reponame}"))
      .done( ->
        mkdir_path = '.'
        for part in cache_path.split('/')
          do (part) ->
            mkdir_path += "/#{part}"
            try
              fs.mkdirSync(mkdir_path)
            catch e
              #pass

        paths = glob.sync("#{tmpextpath}/*.js")
        for file in paths
          do (file) ->
            filename = file.split('/').slice(-1)
            fs.renameSync file, "#{cache_path}/#{filename}"
        outer.resolve()
      )

      promises.push outer.promise

  Q.all(promises)
  .done( ->
    wrench.rmdirSyncRecursive './tmp'
    for ext in exts
      do (ext) ->
        filename = "#{cache_path}/socialite.#{ext}.js"
        if fs.existsSync(filename)
          print "Found #{ext}.\n"
          fs.renameSync filename, "#{path}/socialite.#{ext}.js"
          resolved_exts.push ext
    wrench.rmdirSyncRecursive cache_path if cache_path[0] == '.'
    diff = _.difference(exts,resolved_exts)
    if diff.length
      throw "Unable to resolve extension(s) #{diff.join(', ')} in any sources!"
    callback?())

install_socialite = (callback) ->
  [repo, jspath] = settings.SOCIALITE_SOURCE.split '#'
  Q.when(_handle_gh_download(repo, "./components/socialite"))
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
  [repo, path] = settings.SOCIALITE_SOURCE.split '#'
  js = fs.readFileSync("./components/socialite/#{path}").toString() + "\n"
  paths = glob.sync("#{settings.EXTENSIONS_PATH}/*.js")
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
    ghdl = require 'github-download'
    wrench = require 'wrench'
    glob = require 'glob'
    copysync = require 'copysync'
    _ = require 'underscore'
    _.str = require 'underscore.string'
    _.mixin(_.str.exports())
  catch e
    throw "Please run 'npm install' before continuing. (caught #{e})"
  callback?()

_handle_sysio = (proc, name) ->
  dfd = Q.defer()

  proc.stderr.on 'data', (data) ->
    process.stderr.write data.toString()
  proc.stdout.on 'data', (data) ->
    print data.toString()
  proc.on 'exit', (code) ->
    dfd.reject("'#{name}' exited with error code: #{code}") unless code is 0
    dfd.resolve()
  dfd.promise

_handle_gh_download = (repo, dest, name) ->
  dfd = Q.defer()
  ghdl(repo, dest)
  .on('end', ->
    dfd.resolve dest
  )
  .on('error', (e) ->
    dfd.reject("'{name}' failed to download: #{e}")
  )
  dfd.promise
