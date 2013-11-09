optimist = require 'optimist'

# Parsing Command Line.
options = optimist.usage("""
  Usage: mono <command>'

  Use environment variables to set application variables `port=80 mono`
""")
# .option 'environment',
#   alias   : 'e'
#   desc    : 'set environment'
#   default : null
# .option 'port',
#   alias   : 'p'
#   desc    : 'http port'
#   default : null
# .option 'host',
#   alias   : 'h'
#   desc    : 'http host'
#   default : null
.option 'help',
  alias   : 'h'
.check (argv) ->
  throw '' if argv.help
.argv