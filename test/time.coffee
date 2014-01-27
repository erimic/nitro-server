User    = require '../app/models/user'
Storage = require '../app/controllers/storage'
time    = require '../app/utils/time'
setup   = require './setup'
should  = require 'should'

global.DEBUG = true

describe 'Time', ->

  _user =
    name: 'User - Time'
    email: 'time@inter.net'
    password: 'hunter2'

  userId = null
  listId = null
  taskId = null
  now = null

  before (done) -> setup ->
    user = null
    Storage.add(_user)
    .then (_user) ->
      user = _user
      userId = user.id
      user.createList name: 'List for timestamps'
    .then (_listId) ->
      listId = _listId
      user.createTask name: 'Task for timestamps', listId: listId
    .then (_taskId) ->
      taskId = _taskId
      done()

  beforeEach ->
    now = Date.now()

  it 'should create timestamps for a task', (done) ->

    time.createTask(taskId, now)
    .then ->
      time.read('task', taskId)
    .then (times) ->
      times.should.eql
        id: taskId
        listId: now
        name: now
        notes: now
        priority: now
        completed: now
        date: now
      done()
    .fail (err) ->
      console.log err

  it 'should create timestamps for a list', (done) ->

    time.createList(listId, now)
    .then ->
      time.read('list', listId)
    .then (times) ->
      times.should.eql
        id: listId
        name: now
        tasks: now
      done()
    .fail (err) ->
      console.log err

  it 'should create timestamps for a pref', (done) ->

    time.createPref(userId, now)
    .then ->
      time.read('pref', userId)
    .then (times) ->
      times.should.eql
        id: userId
        sort: now
        night: now
        language: now
        weekStart: now
        dateFormat: now
        confirmDelete: now
        moveCompleted: now
      done()
    .fail (err) ->
      console.log err

  it 'should timestamps for a task', (done) ->

    time.read('task', taskId, 'name').then (times) ->
      times.name.should.be.a.Number
      done()

  it 'should timestamps for a list', (done) ->

    time.read('list', listId, 'name').then (times) ->
      times.name.should.be.a.Number
      done()

  it 'should timestamps for a pref', (done) ->

    time.read('pref', userId, 'sort').then (times) ->
      times.sort.should.be.a.Number
      done()

  it 'should update a task timestamp', (done) ->

    time.update('task', taskId, 'name', now)
    .then ->
      time.read('task', taskId, 'name')
    .then (times) ->
      times.name.should.equal now
      done()

  it 'should update a list timestamp', (done) ->

    time.update('list', listId, 'name', now)
    .then ->
      time.read('list', listId, 'name')
    .then (times) ->
      times.name.should.equal now
      done()

  it 'should update a pref timestamp', (done) ->

    time.update('pref', userId, {sort: now, dateFormat: now})
    .then ->
      time.read('pref', userId, ['sort', 'dateFormat'])
    .then (times) ->
      times.sort.should.equal now
      times.dateFormat.should.equal now
      done()

  it 'should destroy a task timestamp', (done) ->

    time.destroy('task', taskId)
    .then ->
      time.read('task', taskId)
    .fail (err) ->
      err.should.equal 'err_no_row'
      done()

  it 'should destroy a list timestamp', (done) ->

    time.destroy('list', listId)
    .then ->
      time.read('list', listId)
    .fail (err) ->
      err.should.equal 'err_no_row'
      done()

  it 'should destroy a pref timestamp', (done) ->

    time.destroy('pref', userId)
    .then ->
      time.read('pref', userId)
    .fail (err) ->
      err.should.equal 'err_no_row'
      done()

