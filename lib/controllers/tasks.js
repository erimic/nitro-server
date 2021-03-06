const passport = require('passport')
const logger = require('../logger.js')
const User = require('../models/user')
const List = require('../models/list')
const Task = require('../models/task')

const helpers = require('./helpers.js')
const tasksDetails = helpers.tasksDetails
const fullTaskAttributes = helpers.fullTaskAttributes

// allow updates to go through that are this many seconds behind
const UPDATE_THRESHOLD = 20000

const tasks = require('express').Router()
tasks.use(passport.authenticate('bearer', { session: false }))

tasks.get('/:listid', (req, res) => {
  tasksDetails(false, req.query, req.user, req.params.listid)
    .then(data => {
      if (typeof req.query.tasks !== 'undefined') {
        return res.send(data.tasks)
      }
      res.send(data)
    })
    .catch(err => {
      logger.error(
        {
          userId: req.user,
          listId: req.params.listid,
          err: err
        },
        'GET list'
      )
      res.status(err.code).send(err)
    })
})
tasks.get('/:listid/tasks', (req, res) => {
  tasksDetails(true, req.query, req.user, req.params.listid)
    .then(data => {
      res.send(data)
    })
    .catch(err => {
      logger.error(
        {
          userId: req.user,
          listId: req.params.listid,
          err: err
        },
        'GET tasks'
      )
      res.status(err.code).send(err)
    })
})

tasks.patch('/:listid', function(req, res) {
  const query = {
    attributes: [
      'id',
      'name',
      'sort',
      'updatedAt',
      'createdAt',
      'notes',
      'order'
    ],
    include: [
      {
        model: User,
        attributes: ['id', 'friendlyName', 'email'],
        where: {
          id: req.user
        }
      }
    ]
  }
  List.findById(req.params.listid, query)
    .then(function(list) {
      if (list) {
        if (
          list.updatedAt.getTime() - UPDATE_THRESHOLD <
          new Date(req.body.updatedAt).getTime()
        ) {
          const payload = {}
          const allowedUpdates = ['name', 'sort'] // notes not allowed for v1
          allowedUpdates.forEach(function(key) {
            if (key in req.body) {
              payload[key] = req.body[key]
              if (key === 'name' && list[key].slice(0, 9) === 'nitrosys-') {
                payload[key] = list[key]
              } else if (
                key === 'name' &&
                payload[key].slice(0, 9) === 'nitrosys-'
              ) {
                payload[key] = payload[key].slice(9)
              }
            }
          })
          // truncate names for STRING
          if ('name' in payload) {
            payload.name = (payload.name || '').substring(0, 255)
          }
          // order has a special update
          if ('order' in req.body) {
            // makes sure same length
            if (list.order.length === req.body.order.length) {
              let shouldUpdate = true
              // then goes through all the keys and sees if they're the same
              list.order.forEach(function(key) {
                if (req.body.order.indexOf(key) === -1) {
                  shouldUpdate = false
                }
              })
              if (shouldUpdate) {
                payload.order = req.body.order
              }
            }
          }
          list
            .update(payload)
            .then(function(list) {
              res.send(list)
            })
            .catch(function(err) {
              logger.error(
                {
                  userId: req.user,
                  listId: req.params.listid,
                  err: err
                },
                'PATCH list'
              )
              res.status(500).send({ message: 'Internal server error.' })
            })
        } else {
          res.send(list.toJSON())
        }
      } else {
        res.status(404).send({ message: 'List could not be found.' })
      }
    })
    .catch(function(err) {
      logger.error(
        {
          userId: req.user,
          listId: req.params.listid,
          err: err
        },
        'PATCH list'
      )
      res.status(400).send({ message: 'Invalid input syntax.' })
    })
})
tasks.post('/:listid', function(req, res) {
  const query = {
    attributes: ['id', 'order'],
    include: [
      {
        model: User,
        attributes: ['id'],
        where: {
          id: req.user
        }
      }
    ]
  }
  List.findById(req.params.listid, query)
    .then(function(list) {
      if (list) {
        // todo: proper validation?
        const adding = req.body.tasks.map(function(item) {
          return {
            name: (item.name || '').substring(0, 255),
            type: item.type,
            notes: (item.notes || '').substring(0, 51200), // 50kb
            completed: item.completed,
            date: item.date,
            deadline: item.deadline,
            // must be specified here, otherwise the relation isn't made
            listId: list.id
          }
        })
        // they have permission to add into that list
        Task.bulkCreate(adding, {
          validate: true
        })
          .then(function(done) {
            const result = JSON.parse(JSON.stringify(done))

            // pushes new tasks onto the end of the list order
            list
              .update({
                order: result
                  .map(function(item) {
                    return item.id
                  })
                  .reverse()
                  .concat(JSON.parse(JSON.stringify(list.order)))
              })
              .then(function(list) {
                res.send({
                  message: 'Created Tasks.',
                  tasks: result.map(function(item, key) {
                    item.originalId = req.body.tasks[key].id
                    item.priority = item.priority === null ? 0 : item.priority
                    return item
                  })
                })
              })
          })
          .catch(function(err) {
            logger.error(
              {
                userId: req.user,
                listId: req.params.listid,
                err: err
              },
              'POST list'
            )
            res.status(400).send(err)
          })
      } else {
        res.status(404).send({ message: 'List could not be found.' })
      }
    })
    .catch(function(err) {
      logger.error(
        {
          userId: req.user,
          listId: req.params.listid,
          err: err
        },
        'POST list'
      )
      res.status(400).send({ message: 'Invalid input syntax.' })
    })
})
tasks.patch('/:listid/tasks', function(req, res) {
  if (
    req.body &&
    'tasks' in req.body &&
    Object.keys(req.body.tasks).length > 0
  ) {
    List.findById(req.params.listid, {
      include: [
        {
          model: User,
          attributes: ['id'],
          where: {
            id: req.user
          }
        },
        {
          model: Task,
          attributes: fullTaskAttributes,
          where: {
            id: Object.keys(req.body.tasks)
          }
        }
      ]
    })
      .then(function(retrieved) {
        if (
          retrieved &&
          retrieved.tasks.length === Object.keys(req.body.tasks).length
        ) {
          const updateSingle = function(model) {
            return new Promise(function(resolve, reject) {
              const newData = req.body.tasks[model.id]
              if (
                model.updatedAt.getTime() - UPDATE_THRESHOLD <
                new Date(newData.updatedAt).getTime()
              ) {
                const payload = {}
                const allowedUpdates = [
                  'name',
                  'notes',
                  'type',
                  'completed',
                  'date',
                  'deadline',
                  'priority'
                ]
                allowedUpdates.forEach(function(key) {
                  if (key in newData) {
                    if (key === 'name') {
                      payload[key] = (newData[key] || '').substring(0, 255) // STRING
                    } else if (key === 'notes') {
                      payload[key] = (newData[key] || '').substring(0, 51200) // 50KB
                    } else if (key === 'priority') {
                      if (typeof newData[key] === 'number') {
                        payload[key] = Math.max(Math.min(newData[key], 3), 0) // needs to be between 3 & 0
                      }
                    } else {
                      payload[key] = newData[key]
                    }
                  }
                })
                // apply the updates
                model
                  .update(payload)
                  .then(resolve)
                  .catch(reject)
              } else {
                resolve(model)
              }
            })
          }
          const promises = retrieved.tasks.map(function(task) {
            return updateSingle(task)
          })
          Promise.all(promises)
            .then(function(data) {
              // set the update so the client can pick up on changes on this list
              retrieved.changed('updatedAt', true)
              retrieved
                .update({
                  updatedAt: new Date()
                })
                .then(function(list) {
                  res.send({
                    message: 'Update Success',
                    tasks: data.map(t => {
                      t.priority = t.priority === null ? 0 : t.priority
                      return t
                    })
                  })
                })
            })
            .catch(function(err) {
              logger.error(
                {
                  userId: req.user,
                  listId: req.params.listid,
                  err: err
                },
                'PATCH tasks'
              )
              res.status(500).send({ message: 'Internal Server Error' })
            })
        } else {
          const specifically = Object.keys(req.body.tasks)
          if (retrieved) {
            retrieved.tasks.forEach(function(item) {
              const index = specifically.indexOf(item.id)
              if (index > -1) {
                specifically.splice(index, 1)
              }
            })
          }
          res.status(404).send({
            message: 'Tasks could not be found.',
            items: specifically
          })
        }
      })
      .catch(function(err) {
        logger.error(
          {
            userId: req.user,
            listId: req.params.listid,
            err: err
          },
          'PATCH tasks'
        )
        res.status(400).send({ message: 'Invalid input syntax.' })
      })
  } else {
    res.status(400).send({ message: 'Tasks not supplied or empty.' })
  }
})
tasks.delete('/:listid', function(req, res) {
  if (req.body && 'tasks' in req.body && req.body.tasks.length > 0) {
    List.findById(req.params.listid, {
      attributes: ['id', 'order'],
      include: [
        {
          model: User,
          attributes: ['id'],
          where: {
            id: req.user
          }
        },
        {
          model: Task,
          attributes: ['id'],
          where: {
            id: req.body.tasks
          }
        }
      ]
    })
      .then(function(retrieved) {
        if (retrieved && retrieved.tasks.length === req.body.tasks.length) {
          // remove item if it's found
          const newOrder = JSON.parse(JSON.stringify(retrieved.order)).filter(
            function(item) {
              return req.body.tasks.indexOf(item) === -1
            }
          )
          retrieved
            .update({
              order: newOrder
            })
            .then(function() {
              Task.destroy({
                where: {
                  id: req.body.tasks
                }
              }).then(function(data) {
                res.send({
                  message: 'Successfully deleted tasks.',
                  data: req.body.tasks
                })
              })
            })
            .catch(function(err) {
              logger.error(
                {
                  userId: req.user,
                  listId: req.params.listid,
                  err: err
                },
                'DELETE list'
              )
              res.status(500).send({ message: 'An internal error occured.' })
            })
        } else {
          const specifically = req.body.tasks
          if (retrieved) {
            retrieved.tasks.forEach(function(item) {
              const index = specifically.indexOf(item.id)
              if (index > -1) {
                specifically.splice(index, 1)
              }
            })
          }
          res.status(404).send({
            message: 'Tasks could not be found.',
            items: specifically
          })
        }
      })
      .catch(function(err) {
        logger.error(
          {
            userId: req.user,
            listId: req.params.listid,
            err: err
          },
          'DELETE list'
        )
        res.status(400).send({ message: 'Invalid input syntax.' })
      })
  } else {
    res.status(400).send({ message: 'Tasks not supplied or empty.' })
  }
})
module.exports = tasks
