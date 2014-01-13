// Tiny wrapper over node fs module that makes its API handy, consistent and fixes legacy bugs.
//
// By handy I mean that it automatically creates parent directories, deletes not empty directories
// and other frequently needed things.
//
// Fetures:
//
// - createDirectory should create directory and parents if needed
// - deleteDirectory should delete directory with its content
// - delete should delete file or directory with its content
// - writeFile should write or overwrite file and create parents if needed
// - readFileSplittedBy should read file splitted by expression
// - appendFile should append file and create parents if needed
// - writeFileAtomically should atomically write or overwrite file and create parents if needed
// - readDirectory should list directory content recursively
// - copy should copy or overwrite file and create parents if needed
// - createTemporaryDirectory should create empty temporarry directory

var fs     = require('fs')
var fsPath = require('path')
var util   = require('util')
var os     = require('os')

// Async helpers.
var fork = function(errCallback, cb){
  if(!errCallback) throw new Error('no cb for error for fork')
  return function(){
    var err = arguments[0]
    var argsWithoutError = [].slice.call(arguments, 1) || []
    if(err) return errCallback(err)
    if(cb) cb.apply(null, argsWithoutError)
  }
}
var asyncEach = function(list, onEach, cb){
  var processNext = function(i){
    if(i == list.length) return cb()
    try{
      var next = function(err){
        if(err) cb(err)
        else processNext(i + 1)
      }
      if(onEach.length == 2) onEach(list[i], next)
      else onEach(list[i], i, next)
    }catch(e){cb(e)}
  }
  processNext(0)
}

// fs2.
var fs2 = {}

// Copying functions from standard `fs` module.
for(var attr in fs){fs2[attr] = fs[attr]}

// Create directory and all parent directories if they not exists.
fs2.createDirectory = function(path, cb){
  fs.mkdir(path, function(err){
    if(!err || err.code == 'EEXIST') return cb()
    if(err.code == 'ENOENT')
      fs2.createDirectory(fsPath.dirname(path), fork(cb, function(){
        fs.mkdir(path, cb)
      }))
    else cb(err)
  })
}

// Delete file or directory (empty or not).
fs2.delete = function(path, cb){
  fs.unlink(path, function(err){
    if(!err) return cb()
    if(err.code == 'ENOENT') cb()
    else if(err.code == 'EPERM') fs2.deleteDirectory(path, cb)
    else cb(err)
  })
}

// Delete directory (empty or not)
fs2.deleteDirectory = function(path, cb){
  fs.rmdir(path, function(err){
    if(!err) return cb()
    if(err.code == 'ENOENT') cb()
    else if(err.code == 'ENOTEMPTY'){
      fs.readdir(path, fork(cb, function(entries){
        asyncEach(entries, function(entry, next){
          var child = fsPath.join(path, entry)
          fs2.delete(child, next)
        }, fork(cb, function(){
          fs.rmdir(path, cb)
        }))
      }))
    }else cb(err)
  })
}

// Write file and create parent dirs if not exists.
fs2.writeFile = function(){
  var args = [].slice.call(arguments, 0)
  var path = args[0]
  var cb = args[args.length - 1]
  var args = args.slice(0, arguments.length - 1)
  args.push(function(err){
    if(!err) return cb()
    if(err.code == 'ENOENT')
      fs2.createDirectory(fsPath.dirname(path), fork(cb, function(){
        args.pop()
        args.push(cb)
        fs.writeFile.apply(null, args)
      }))
    else cb(err)
  })
  fs.writeFile.apply(null, args)
}

fs2.appendFile = function(){
  var args = [].slice.call(arguments, 0)
  var path = args[0]
  var cb = args[args.length - 1]
  var args = args.slice(0, arguments.length - 1)
  args.push(function(err){
    if(!err) return cb()
    if(err.code == 'ENOENT')
      fs2.createDirectory(fsPath.dirname(path), fork(cb, function(){
        args.pop()
        args.push(cb)
        fs.appendFile.apply(null, args)
      }))
    else cb(err)
  })
  fs.appendFile.apply(null, args)
}

// Write file atomically, if file exists it will be overriden. It writes content to temporarry
// file and then atomically rename temporarry file to the real.
fs2.writeFileAtomically = function(){
  var args = [].slice.call(arguments, 0)
  var path = args[0]
  var cb = args[args.length - 1]
  var tmpPath = path + '.tmp'
  args.shift()
  args.unshift(tmpPath)
  args.pop()
  args.push(function(err){
    if(err) return cb(err)
    // Atomically renaming temporarry file to real file.
    fs.rename(tmpPath, path, cb)
  })
  // Writing file.
  fs2.writeFile.apply(null, args)
}

// File or directory existence.
fs2.exists = function(path, cb){
  fs.stat(path, function(err, stat){
    if(err && err.code == 'ENOENT') return cb(null, false)
    if(err) return cb(err)
    cb(null, true)
  })
}

// File existence.
fs2.isFile = function(path, cb){
  fs.stat(path, function(err, stat){
    if(err && err.code == 'ENOENT') return cb(null, false)
    if(err) return cb(err)
    cb(null, stat.isFile())
  })
}

// Directory existence.
fs2.isDirectory = function(path, cb){
  fs.stat(path, function(err, stat){
    if(err && err.code == 'ENOENT') return cb(null, false)
    if(err) return cb(err)
    cb(null, stat.isDirectory())
  })
}

// List directory content, accept `recursive` and `relative` options.
fs2.readDirectory = function(path, options, cb){
  cb = cb || options
  var basePath = options.relative ? null : path
  var readDirectory = function(path, base, cb){
    var list = []
    fs.readdir(path, fork(cb, function(entries){
      asyncEach(entries, function(entry, next){
        var entryPath = fsPath.join(path, entry)
        var entryBasePath = base ? fsPath.join(base, entry) : entry
        fs2.isDirectory(entryPath, fork(cb, function(isDirectory){
          if(isDirectory){
            list.push({type: 'directory', path: entryBasePath})
            if(options.recursive)
              readDirectory(entryPath, entryBasePath, fork(cb, function(entryList){
                Array.prototype.push.apply(list, entryList)
                next()
              }))
            else next()
          }else{
            list.push({type: 'file', path: entryBasePath})
            next()
          }
        }))
      }, fork(cb, function(){
        cb(null, list)
      }))
    }))
  }
  readDirectory(path, basePath, cb)
}

// Copy or overwrite file and create parents if needed.
fs2.copy = function(from, to, cb){
  var copy = function(from, to, createParents, cb){
    var fromStream = fs.createReadStream(from)
    var toStream = fs.createWriteStream(to)
    fromStream.pipe(toStream)

    // If errors are in both streams callback will be called twice,
    // need this to report only the first error.
    var callbackCalled = false
    var callbackForReadStream = function(){
      if(callbackCalled) return
      callbackCalled = true
      fromStream.destroy()
      toStream.destroy()
      cb.apply(null, arguments)
    }
    fromStream.on('error', callbackForReadStream)
    fromStream.on('close', callbackForReadStream)

    // If errors are in both streams callback will be called twice,
    // need this to report only the first error.
    // It also creates parents for destination if needed.
    var callbackForWriteStream = function(err){
      if(callbackCalled) return
      callbackCalled = true
      fromStream.destroy()
      toStream.destroy()
      if(createParents && err.code == 'ENOENT')
        // Parents for detination not exist, creating it.
        fs2.createDirectory(fsPath.dirname(to), fork(cb, function(){
          copy(from, to, false, cb)
        }))
      else cb.apply(null, arguments)
    }
    toStream.on('error', callbackForWriteStream)
  }
  copy(from, to, true, cb)
}

// Get empty temporarry directory.
fs2.getTemporaryDirectory = function(cb){
  var tmpDir = os.tmpDir()
  tmpDir = tmpDir.slice(0, (tmpDir.length - 1))
  fs2.deleteDirectory(tmpDir, fork(cb, function(){
    fs2.createDirectory(tmpDir, fork(cb, function(){
      fs2.readDirectory(tmpDir, fork(cb, function(list){
        cb(null, tmpDir)
      }))
    }))
  }))
}

fs2.readFileSplittedBy = function(filePath, splitExpression, lineCb, cb){
  // Guard to call callback only once.
  var callbackCalled = false
  var originalCb = cb
  cb = function(){
    if(callbackCalled) return
    callbackCalled = true
    originalCb.apply(null, arguments)
  }

  var stream = fs2.createReadStream(filePath)
  stream.setEncoding('utf8')

  var buffer = []
  var flushBuffer = function(chunk){
    if(chunk) buffer.push(chunk)
    if(buffer.length > 0){
      lineCb(buffer.join())
      buffer = []
    }
  }

  stream.on('data', function(chunk){
    var lineChunks = chunk.split(splitExpression)
    // No newlines.
    if(lineChunks.length === 1){
      buffer.push(chunk)
    // At least one newline.
    }else{
      // Adding first line chunk to buffer and processing it.
      flushBuffer(lineChunks[0])

      // Processing newlines in the middle.
      for(var i = 1; i < lineChunks.length - 1; i++) flushBuffer(lineChunks[i])

      // Checking if the last symbol is newline.
      var lastChunk = lineChunks[lineChunks.length - 1]
      if(lastChunk !== '') buffer.push(lastChunk)
    }
  })
  stream.on('error', function(err){cb(err)})
  stream.on('end', function(){
    flushBuffer()
    cb()
  })
  stream.resume()
}

// Validates strings doesn't contain dangerous characters.
fs2.ensureSafe = function(){
  for(var name in arguments){
    if(/\.\./.test(name)) throw new Error("unsafe path (" + name + ")!")
  }
}

// Synchronizing.
// fs2/sync is optional module and its dependency - synchronize.js not included in
// fs2 dependency modules list, You should install it by itself.
var sync = require('synchronize')

sync(fs2,
  'createDirectory',
  'delete',
  'deleteDirectory',
  'writeFile',
  'writeFileAtomically',
  'exists',
  'isFile',
  'isDirectory',
  'readDirectory',
  'copy',

  'readFile',
  'writeFile',
  'stat',

  'getTemporaryDirectory',

  'close',
  'createReadStream',
  'createWriteStream'
  )

// Export.
module.exports = fs2

// Need this for fs2 tests.
module.exports.fork = fork
module.exports.asyncEach = asyncEach