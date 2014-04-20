_             = require 'underscore'
child_process = require 'child_process'
sync          = require 'synchronize'

module.exports = child_process2 = _({}).extend child_process,
  exec2: (command, options..., cb) ->
    options = options[0] || {}
    throw new Error 'no cb for exec' unless cb
    child_process.exec command, options, (err, stdout, stderr) ->
      return cb new Error(stderr) if err
      cb null, stdout

  exec3: (command, args, options, data, cb) ->
    {spawn} = require 'child_process'
    throw new Error 'no cb for exec' unless cb
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

# Synchronizing.
sync child_process2, 'exec2', 'exec3'