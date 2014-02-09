express = require 'express'
cors    = require 'cors'
Auth    = require '../controllers/auth'
Mail    = require '../controllers/mail'
User    = require '../models/user'
Log     = require '../utils/log'

log = Log 'Router', 'magenta'

app = express()

app.configure ->

  # Parse POST requests
  app.use express.json()
  app.use express.urlencoded()

  # Allow Cross-Origin Resource Sharing
  app.use cors()

# -----------------------------------------------------------------------------
# Routes
# -----------------------------------------------------------------------------

routes = [
  'login'
  'register'
  'reset'
  'root'
  '404'
  # 'oauth'
  # 'payment'
]

# Bind an array of routes to the server
for route in routes
  route = require '../routes/' + route
  for path in route
    if path.type is 'get'
      log 'GET ', path.url
    else
      log 'POST', path.url
    app[path.type] path.url, path.handler

module.exports = app
