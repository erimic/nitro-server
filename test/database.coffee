should = require 'should'
database = require '../app/controllers/query'

setup   = require './setup'
should  = require 'should'

# Testing the database storage engine

describe 'Database', ->

  user =
    name: 'Jimmy'
    email: 'jimmy@gmail.com'
    password: 'blah'
    pro: 0

  list =
    user_id: null
    name: 'List 1'

  before setup

  describe '#setup', ->

    it 'should have access to lists, tasks, etc.', ->
      database.task.should.be.ok
      database.list.should.be.ok
      database.user.should.be.ok


  describe '#user', ->

    it 'should create a new user', (done) ->

      database.user.create(user).then (id) ->
        user.id = id
        done()

    it 'should store the creation time', (done) ->

      database.user.read(user.id, 'created_at').then (info) ->
        info.created_at.should.be.an.instanceOf Date
        user.created_at = info.created_at
        done()

    it 'should fetch all user information', (done) ->

      database.user.read(user.id).then (info) ->
        info.should.eql user
        done()

    it 'should update an existing user', (done) ->

      user.name = 'James'
      model = name: user.name
      database.user.update(user.id, model).then -> done()

    it 'should fetch a updated information', (done) ->

      database.user.read(user.id, 'name').then (info) ->
        info.name.should.equal user.name
        done()

    it 'should fetch multiple values', (done) ->

      database.user.read(user.id, ['name', 'email']).then (info) ->
        info.should.eql
          name: user.name
          email: user.email
        done()

    it 'should delete an existing user', (done) ->

      database.user.destroy(user.id).then -> done()

    it 'should fail when fetching a user that does not exist', (done) ->

      database.user.read(user.id, 'name').fail -> done()

    it 'should fail when updating a user that does not exist', (done) ->

      model = email: 'james@gmail.com'
      database.user.update(user.id, model).fail -> done()

    it 'should fail when destroying a user that does not exist', (done) ->

      database.user.destroy(user.id).fail -> done()

    it 'should create another user', (done) ->

      delete user.id
      delete user.created_at

      database.user.create(user).then (id) ->
        user.id = id
        done()


  describe '#list', ->


    before ->
      list.user_id = user.id

    it 'should create a new list', (done) ->

      database.list.create(list).then (id) ->
        list.id = id
        done()

    it 'should read an existing list', (done) ->

      database.list.read(list.id).then (info) ->
        info.should.eql list
        done()

    it 'should update an existing list', (done) ->

      list.name = 'List 1 - Updated'
      model = name: list.name
      database.list.update(list.id, model).then -> done()

    it 'should read an updated list', (done) ->

      database.list.read(list.id, 'name').then (info) ->
        info.should.eql
          name: list.name
        done()

    it 'should destroy an existing list', (done) ->

      database.list.destroy(list.id).then -> done()

    it 'should create another list', (done) ->

      delete list.id
      database.list.create(list).then (id) ->
        list.id = id
        done()


  describe '#task', ->

    task =
      user_id: null
      list_id: null
      name: 'Task 1'
      notes: 'Some notes'
      priority: 2
      date: 0
      completed: 0

    before ->
      task.user_id = user.id
      task.list_id = list.id

    it 'should create a new task', (done) ->

      database.task.create(task).then (id) ->
        task.id = id
        done()

    it 'should read an existing task', (done) ->

      database.task.read(task.id).then (info) ->
        task.should.eql info
        done()

    it 'should update an existing task', (done) ->

      task.name = 'Task 1 - Updated'
      model = name: task.name
      database.task.update(task.id, model).then -> done()

    it 'should read an updated task', (done) ->

      database.task.read(task.id, 'name').then (info) ->
        info.name.should.equal task.name
        done()

    it 'should destroy an existing task', (done) ->

      database.task.destroy(task.id).then -> done()


