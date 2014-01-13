global.expect = require('chai').expect
global.p      = console.log.bind(console)
sync          = require 'synchronize'
async         = sync.asyncIt
_             = require 'underscore'
fs            = require 'fs'

fs2 = require '../fs2'
{ReadStream, WriteStream, NodeWriteReadStream, StringStream} = require '../streams'

describe "streams", ->
  tmpDir = null
  beforeEach async ->
    tmpDir = fs2.getTemporaryDirectory()

  it "should read file", async ->
    path = "#{tmpDir}/some.txt"
    fs2.writeFile path, 'some content'

    buff = []
    ReadStream.fromFile(path).open (read) ->
      buff.push chunk while chunk = read(2)
    expect(buff.join('')).to.eql 'some content'

  it "should read full file", async ->
    path = "#{tmpDir}/some.txt"
    fs2.writeFile path, 'some content'
    expect(ReadStream.fromFile(path).read()).to.eql 'some content'

  it "should write file", async ->
    path = "#{tmpDir}/some.txt"
    WriteStream.fromFile(path).open (write) ->
      write 'some '
      write 'content'
    expect(fs2.readFile(path, 'utf8')).to.eql 'some content'

  it "should copy from read stream into write stream", async ->
    fromPath = "#{tmpDir}/from.txt"
    toPath   = "#{tmpDir}/to.txt"
    fs2.writeFile(fromPath, 'some content')

    WriteStream.fromFile(toPath).open (write) ->
      ReadStream.fromFile(fromPath).open (read) ->
        write chunk while chunk = read(2)

    expect(fs2.readFile(toPath, 'utf8')).to.eql 'some content'

  it "write to read stream", async ->
    wr = new NodeWriteReadStream()
    chunks = []
    wr.on 'data', (chunk) -> chunks.push chunk
    wr.on 'end', -> chunks.push 'end'
    wr.write 'Hello', sync.defer()
    sync.await()
    wr.write ' world.', sync.defer()
    sync.await()
    wr.end sync.defer()
    sync.await()
    expect(chunks).to.eql ['Hello', ' world.', 'end']

  it "should connect producer/writer with consumer/reader (from s3)", async ->
    events = []
    chunks = []

    produce = (writeStream) ->
      writeStream.open (write) ->
        write 'Hello'
        write ' world.'
        events.push 'producer finished writing'
      events.push 'producer finished'

    consume = (nodeReadStream, callback) ->
      nodeReadStream.on 'data', (chunk) -> chunks.push chunk
      nodeReadStream.on 'end', ->
        chunks.push 'end'
        events.push 'consumer finished reading'
        # Don't use `nextTick` its too quick and sometimes finishes even
        # without waiting for it.
        setTimeout (->
          events.push 'consumer finished'
          callback?()
        ), 10

    open  = ->
      wrs = new NodeWriteReadStream()
      consume wrs, sync.defer()
      wrs
    close = ->

    writeStream = new WriteStream(open, close)
    writeStream.alsoWaitFor = -> sync.await()

    produce writeStream
    expect(chunks).to.eql ['Hello', ' world.', 'end']
    expect(events).to.eql [
      'producer finished writing',
      'consumer finished reading',
      'consumer finished',
      'producer finished'
    ]

  it "should create stream from string", async ->
    from = new StringStream 'some content'

    cb = _(sync.defer()).once()
    from.on 'error', (error) -> cb error

    to = fs.createWriteStream "#{tmpDir}/to"
    to.on 'error', (error) -> cb error
    to.on 'close',         -> cb()

    from.pipe(to)
    sync.await()

    data = fs.readFileSync("#{tmpDir}/to").toString()
    expect(data).to.eql "some content"

