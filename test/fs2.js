global.expect = require('chai').expect
global.p      = console.log.bind(console)

var os     = require('os')
var fsPath = require('path')
var fs2    = require('../fs2')
var fork   = fs2.fork

describe("fs2", function(){
  // Creating and removing empty tmp directory.
  var tmpDir = null
  beforeEach(function(next){
    fs2.getTemporaryDirectory(fork(next, function(dir){
      tmpDir = dir
      next()
    }))
  })

  // Helper to fill directory with some content.
  var fillWithSampleContent = function(cb){
    fs2.writeFile(tmpDir + '/first file', 'first file', fork(cb, function(){
      fs2.createDirectory(tmpDir + '/directory', fork(cb, function(){
        fs2.writeFile(tmpDir + '/directory/second file', 'second file', fork(cb, function(){
          fs2.writeFile(tmpDir + '/directory/third file', 'third file', cb)
        }))
      }))
    }))
  }

  it("createDirectory should create directory and parents if needed", function(next){
    var dir = tmpDir + '/parent/directory'
    fs2.createDirectory(dir, fork(next, function(){
      fs2.exists(dir, fork(next, function(exists){
        expect(exists).to.equal(true)
        next()
      }))
    }))
  })

  it("deleteDirectory should delete directory with its content", function(next){
    fillWithSampleContent(fork(next, function(){
      fs2.deleteDirectory(tmpDir, fork(next, function(){
        fs2.exists(tmpDir + '/file', fork(next, function(exists){
          expect(exists).to.equal(false)
          fs2.exists(tmpDir, fork(next, function(exists){
            expect(exists).to.equal(false)
            next()
          }))
        }))
      }))
    }))
  })

  it("delete should delete file or directory with its content", function(next){
    fillWithSampleContent(fork(next, function(){
      fs2.delete(tmpDir + '/directory/second file', fork(next, function(){
        fs2.exists(tmpDir + '/directory/second file', fork(next, function(exists){
          expect(exists).to.equal(false)
          fs2.delete(tmpDir, fork(next, function(){
            fs2.exists(tmpDir + '/file', fork(next, function(exists){
              expect(exists).to.equal(false)
              next()
            }))
          }))
        }))
      }))
    }))
  })

  it("writeFile should write or overwrite file and create parents if needed", function(next){
    var fname = tmpDir + '/parent/file'
    fs2.writeFile(fname, 'some data', fork(next, function(){
      fs2.readFile(fname, 'utf8', fork(next, function(data){
        expect(data).to.equal('some data')
        next()
      }))
    }))
  })

  it("readFileSplittedBy should read file splitted by expression", function(next){
    var fname = tmpDir + '/file'
    fs2.writeFile(fname, "line 1\n\nline 2", fork(next, function(){
      var lines = []
      fs2.readFileSplittedBy(fname, /\n\n/g, function(line){lines.push(line)}, fork(next, function(){
        expect(lines).to.eql(['line 1', 'line 2'])
        next()
      }))
    }))
  })

  it("appendFile should append file and create parents if needed", function(next){
    var fname = tmpDir + '/parent/file'
    fs2.appendFile(fname, 'some data', fork(next, function(){
      fs2.appendFile(fname, ' another data', fork(next, function(){
        fs2.readFile(fname, 'utf8', fork(next, function(data){
          expect(data).to.equal('some data another data')
          next()
        }))
      }))
    }))
  })

  it("writeFileAtomically should atomically write or overwrite file and create parents if needed", function(next){
    var fname = tmpDir + '/parent/file'
    fs2.writeFileAtomically(fname, 'some data', fork(next, function(){
      fs2.readFile(fname, 'utf8', fork(next, function(data){
        expect(data).to.equal('some data')
        fs2.writeFileAtomically(fname, 'another data', fork(next, function(){
          fs2.readFile(fname, 'utf8', fork(next, function(data){
            expect(data).to.equal('another data')
            next()
          }))
        }))
      }))
    }))
  })

  it("readDirectory should list directory content recursively", function(next){
    fillWithSampleContent(fork(next, function(){
      fs2.readDirectory(tmpDir, {recursive: true, relative: true}, fork(next, function(list){
        expect(list).to.eql([
          {type: 'directory', path: 'directory'},
          {type: 'file', path: 'directory/second file'},
          {type: 'file', path: 'directory/third file'},
          {type: 'file', path: 'first file'}
        ])
        next()
      }))
    }))
  })

  it("copy should copy or overwrite file and create parents if needed", function(next){
    fillWithSampleContent(fork(next, function(){
      var another = tmpDir + '/another directory/first file'
      fs2.copy(tmpDir + '/first file', another, fork(next, function(){
        fs2.readFile(another, 'utf8', fork(next, function(data){
          expect(data).to.eql('first file')
          next()
        }))
      }))
    }))
  })

  it("createTemporaryDirectory should create empty temporarry directory", function(next){
    fs2.getTemporaryDirectory(fork(next, function(tmpDir){
      expect(tmpDir).to.be.a('string')
      next()
    }))
  })
})