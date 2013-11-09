sync = require 'synchronize'

exports.execWithSpawn = (command, args, options, data, cb) ->
  {spawn} = require 'child_process'
  throw new Error 'no cb for execWithSpawn' unless cb
  child = spawn command, args, options
  [stdout, stderr, exitCode, size] = [[], [], null, 0]
  join = (list) -> list.map((buffer) -> buffer.toString('utf8')).join()

  child.stdout.on 'data', (buffer) -> size += 1; stdout.push buffer
  child.stderr.on 'data', (buffer) -> stderr.push buffer
  child.on 'error', (err) -> cb err
  exitCode = null
  child.on 'exit', (code) -> exitCode = code
  child.on 'close', ->
    return cb new Error(join(stderr)) unless exitCode == 0
    cb null, join(stdout)
  child.stdin.write data, 'utf8' if data
  child.stdin.end()

sync exports, 'execWithSpawn'