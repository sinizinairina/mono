sync   = require 'synchronize'
stream = require 'stream'
util   = require 'util'
Buffer = require('buffer').Buffer

# ReadStream.
exports.ReadStream = ReadStream = (args...) ->
  [@openFn, @closeFn] = if args[0] instanceof Function then args
  else [(-> args[0])]
  null

ReadStream.size = 100 * 1024

ReadStream::open = (encoding..., cb) ->
  encoding = encoding[0]
  try
    nStream = @openFn()
    nStream.setEncoding encoding if encoding

    [deferCb, error, ended] = [null, null, false]
    nStream.on 'readable',      -> deferCb?()
    nStream.on 'error',   (err) -> error = err; deferCb?()
    nStream.on 'end',           -> ended = true; deferCb?()

    read = (size) ->
      if error then throw error
      else if ended then null
      else
        if (chunk = nStream.read(size || @size)) != null then chunk
        else
          deferCb = sync.defer()
          sync.await()
          deferCb = null
          read(size)
    cb read
  finally
    @closeFn? nStream if nStream

ReadStream::read = (encoding) ->
  buff = []
  @open encoding, (read) -> buff.push read()
  # Buffer.concat buff
  buff.join('')

ReadStream.fromFile = (path) ->
  fs = require 'fs'

  [fileDescriptor, nStream] = [null, null]
  open = ->
    nStream = fs.createReadStream path

    # Opening stream.
    [deferCb, error] = [null, null]
    nStream.on 'open',  (fd)  -> deferCb?(null, fd)
    nStream.on 'error', (err) -> error = err; deferCb?()
    # Waiting for `open` event.
    deferCb = sync.defer()
    fileDescriptor = sync.await()
    deferCb = null
    throw error if error

    nStream
  close = ->
    if fileDescriptor and !nStream.closed
      fs.close fileDescriptor, sync.defer()
      sync.await()
  new ReadStream open, close

ReadStream.fromString = (string) ->
  stream = new ReadStream()
  stream.open = (encoding..., cb) ->
    encoding = encoding[0]
    throw new Error "encoding not supported String stream!" if encoding
    readed = false
    cb (size) ->
      throw new Error "size not supported for String stream!" if size
      return null if readed
      readed = true
      string
  stream.read = (encoding) ->
    throw new Error "encoding not supported String stream!" if encoding
    string
  stream

# WriteStream.
exports.WriteStream = WriteStream = (args...) ->
  [@openFn, @closeFn] = if args[0] instanceof Function then args
  else [(-> args[0])]
  null

WriteStream::open = (cb) ->
  try
    nStream = @openFn()

    [deferCb, error] = [null, null]
    nStream.on 'error', (err) -> error = err; deferCb?()

    # Writing chunk to stream and waiting when it will be flushed.
    write = (args...) ->
      throw error if error
      nStream.write args..., -> deferCb?()
      deferCb = sync.defer()
      sync.await()
      deferCb = null
      throw error if error

    cb write

    nStream.end sync.defer()
    sync.await()

    # If specified also waiting for some external condition.
    @alsoWaitFor?()
  finally
    @closeFn? nStream if nStream

WriteStream.fromFile = (path) ->
  fs = require 'fs'

  open  =           -> fs.createWriteStream path
  close = (nStream) -> nStream.close()
  new WriteStream open, close

# NodeWriteReadStream.
exports.NodeWriteReadStream = NodeWriteReadStream = ->
  @writable = true
  @readable = true

util.inherits NodeWriteReadStream, stream.Stream

NodeWriteReadStream::write  = (chunk, encoding..., callback) ->
  @emit 'data', chunk
  process.nextTick -> callback?()
NodeWriteReadStream::end    = (callback) ->
  @emit 'end'
  process.nextTick -> callback?()
NodeWriteReadStream::pause  = -> @emit 'pause'
NodeWriteReadStream::resume = -> @emit 'resume'

# StringStream.
exports.StringStream = StringStream = (@data) ->
  @readable = true

util.inherits StringStream, stream.Stream

StringStream::onWithoutWrite = StringStream::on
StringStream::on = (name, cb) ->
  @_write() if name == 'data'
  @onWithoutWrite name, cb

StringStream::resume = ->
  @paused = false
  @_write()

# StringStream::read = (size) ->
#   throw new Error "read with size is not supported for StringStream" if size
#   return null if @closed
#   @closed = true
#   @data

StringStream::setEncoding = (@encoding) ->

StringStream::pause = -> @paused = true

StringStream::destroy = ->

StringStream::_write = ->
  process.nextTick =>
    return if @paused or @closed
    if @encoding && Buffer.isBuffer(@data) then @emit 'data', @data.toString(@encoding)
    else @emit 'data', @data
    @emit('end')
    @emit('close')
    @closed = true