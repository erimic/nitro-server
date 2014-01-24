Q        = require 'kew'
connect  = require '../controllers/connect'
Log      = require '../utils/log'

log = Log 'Database', 'blue'
warn = Log 'Database', 'red'

# tables
tables =
  user: require '../database/user'
  list: require '../database/list'
  task: require '../database/task'
  login: require '../database/login'
  register: require '../database/register'

connected = connect.ready.then ->

  log 'Connecting to MySQL'

  db = connect.mysql
  query = Q.bindPromise db.query, db

  # Export query
  module.exports.query = query

  deferred = Q.defer()

  db.connect  (err) ->
    if err
      warn 'Could not connect to MySQL database!'
      return deferred.reject err

    log 'Connected to MySQL server'

    for name, Table of tables
      table = new Table(query)
      table.setup()
      module.exports[name] = table

    deferred.resolve()

  return deferred.promise

module.exports =
  connected: connected