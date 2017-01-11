_ = require "underscore"
logger = (->
  createLogsObject = ->
    default: []

  #depth is changed after printing
  displayLog = ->
    _.each logs, (value, key) ->
      _.each value, (ele) ->
        console.log ele
      delete logs[key]

  logs = createLogsObject()

  log = (->
    depth = 0
    indent = undefined
    res = undefined
    (str, depthChange, setName) ->
      setName = "default"  unless setName
      logs[setName] = []  unless logs[setName]
      if depthChange
        if depthChange > 0
          openingParen = " {"
        else
          openingParen = ""
        if depthChange < 0
          closingParen = "  ".repeat(depth - 1) + "}"
        else
          closingParen = ""
        logs[setName].push closingParen + "  ".repeat(depth) + str + openingParen
        depth += depthChange
      else
        logs[setName].push "  ".repeat(depth) + str
  )()

  displayLog: displayLog
  log: log
)()

log = ->
  logger.log.apply @, arguments
  logger.displayLog()

exports.log = log
exports.logger = logger
