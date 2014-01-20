User    = require '../app/models/user'
Storage = require '../app/controllers/storage'
should  = require 'should'

global.DEBUG = true

describe 'User class', ->

  before ->
    Storage._writeUser = Storage.writeUser
    Storage.writeUser = ->

  after ->
    Storage.writeUser = Storage._writeUser
    delete Storage._writeUser

  it 'should create a new user', ->
    user = new User()

  it 'should create a new using with pre-defined attributes', ->

    attrs =
      id: 30
      name: 'Johnny'
      data_task:
        football: true
      created_at: Date.now()

    user = new User(attrs)

    attrs.id.should.equal          user.id
    attrs.name.should.equal        user.name
    attrs.data_task.should.equal   user.data_task
    attrs.created_at.should.equal  user.created_at

  it 'should allow attributes to be changed', ->

    name = 'Timothy'
    user = new User()

    value = user.set 'name', name

    name.should.equal user.name
    value.should.equal name

  it 'should throttle writes to the db', (done) ->

    start = Date.now()

    fn = Storage.writeUser
    count = 0

    Storage.writeUser = (user, args) ->

      switch count++
        when 0
          args.should.eql ['data_tasks']

        when 1
          args.should.eql ['data_lists', 'data_name', 'data_email']
          diff = Date.now() - start
          diff.should.be.within 200, 205
          Storage.writeUser = fn
          done()

    user = new User(null, 200)
    user.save 'tasks'
    user.save 'lists'
    user.save 'name'
    user.save 'email'

  it 'should get and set data', ->

    user = new User()

    data = user.data 'animals'
    data.should.be.empty

    data.horses = 1

    data = user.data 'animals'
    data.horses.should.equal 1

    user.data 'animals',
      horses: 30

    data = user.data 'animals'
    data.horses.should.equal 30

  it 'should get the index value', ->

    user = new User()

    index = user.index 'cows'
    index.should.equal 0

    user.set 'index_chickens', 30

    index = user.index 'chickens'
    index.should.equal 30

  it 'should increment the index value', ->

    user = new User()

    index = user.index 'pigs'
    index.should.equal 0

    index = user.incrIndex 'pigs'
    index.should.equal 1

    index = user.incrIndex 'pigs'
    index.should.equal 2

  it 'should allow the password to be changed', (done) ->

    id = 300
    password = 'battery horse chicken staple'

    fn = Storage.removeAllLoginTokens
    Storage.removeAllLoginTokens = (userId) ->
      userId.should.equal id
      password.should.equal user.password
      Storage.removeAllLoginTokens = fn
      done()

    user = new User
      id: id
      password: 'hunter2'

    user.setPassword password

  it 'should allow the email to be changed', (done) ->

    id = 33
    email = 'john@smith.com'

    fn = Storage.replaceEmail
    Storage.replaceEmail = (userId, oldEmail, newEmail) ->
      userId.should.equal id
      newEmail.should.equal user.email
      email.should.equal user.email
      Storage.replaceEmail = fn
      done()

    user = new User
      id: id
      email: 'john@gmail.com'

    user.setEmail email


  it 'should be able to find models', ->

    attrs =
      data_task:
        's-0':
          name: 'Task 1'
      data_list:
        's-2':
          name: 'List 3'

    user = new User(attrs)

    # Tasks
    task = user.findModel 'task', 's-0'
    task.name.should.equal 'Task 1'

    # Lists
    list = user.findModel 'list', 's-2'
    list.name.should.equal 'List 3'

    # Should return an object if it doesn't exist
    missing = user.findModel 'task', 's-10'
    missing.should.eql {}


  it 'should be able to detect if a model exists', ->

    attrs =
      data_task:
        's-0':
          name: 'Task 1'

    user = new User(attrs)

    # Existing items should return true
    exists = user.hasModel 'task', 's-0'
    exists.should.be.ok

    # Missing items should return false
    no_model = user.hasModel 'task', 's-100'
    no_model.should.not.be.ok
    no_class = user.hasModel 'Empty', 's-2'
    no_class.should.not.be.ok


  it 'should export an array', ->

    attrs =
      data_task:
        's-0':
          name: 'Task 1'
        's-1':
          deleted: true
        's-2':
          name: 'Task 3'
        's-3':
          name: 'Task 4'
      data_list:
        's-0':
          name: 'List 1'
        's-1':
          deleted: true
        's-2':
          deleted: true
        's-3':
          name: 'List 4'

    user = new User(attrs)

    tasks = user.exportModel 'task'
    lists = user.exportModel 'list'
    empty = user.exportModel 'empty'

    lists.should.be.an.Array
    tasks.should.be.an.Array
    lists.should.have.length 2
    tasks.should.have.length 3

    # Should return our tasks and lists
    tasks[0].name.should.equal 'Task 1'
    lists[1].name.should.equal 'List 4'

    # If the class doesn't exist, it should return an empty array
    empty.should.be.an.Array
    empty.should.be.empty
