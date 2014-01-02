###
           ___  __   __      __            __
    |\ | |  |  |__) /  \    /__` \ / |\ | /  `
    | \| |  |  |  \ \__/    .__/  |  | \| \__,

    ------------------------------------------

    This is the sync code. It's a wee bit crazy.

###


Q       = require 'kew'
Log     = require '../utils/log'
Time    = require '../utils/time'

log      = Log 'Sync', 'cyan'
logEvent = Log 'Sync Event', 'yellow'

# Return the default task object
# I don't think we even use this anymore?
Default = (name) ->

  data =
    Task:
      completed: false
      date: ''
      list: 'inbox'
      name: 'New Task'
      notes: ''
      priority: 1
    List:
      name: 'New List'
      tasks: []

  clone = (obj) ->
    newObj = {}
    for key, value of obj
      newObj[key] = value
    return newObj

  if data[name]
    return clone data[name]


# Does all the useful stuff
class Sync

  constructor: (@user) ->
    @time = new Time(@user)

  # --------------
  # General Events
  # --------------

  # Return all models in database
  fetch: (classname, fn) =>
    return unless fn
    fn @exportModel(classname)


  #####################################
  #    __   __   ___      ___  ___    #
  #   /  ` |__) |__   /\   |  |__     #
  #   \__, |  \ |___ /~~\  |  |___    #
  #                                   #
  #####################################


  # Create a new model
  create: (data, fn) =>

    # Generate new id
    if classname is 'Setting'
      id = 1
      model = @settingsValidate(model)

    else if classname is 'List' and model.id is 'inbox'
      id = model.id
      if @hasModel('List', 'inbox') then return

    else
      id = 's-' + @user.index(classname)
      @user.incrIndex classname
      model.id = id

    # Add task to list
    if classname is 'Task'
      listId = model.list
      @taskAdd id, listId
    else if classname is 'List'
      model.tasks = []

    # Add item to server
    @setModel(classname, id, model)

    # Set timestamp
    timestamp = data[2] or Date.now()
    @time.set classname, id, 'all', timestamp
    log "Created #{ classname }: #{ model.name }"

    # Broadcast event to connected clients
    @broadcast 'create', [classname, model]

    return id



  ####################################
  #         __   __       ___  ___   #
  #   |  | |__) |  \  /\   |  |__    #
  #   \__/ |    |__/ /~~\  |  |___   #
  #                                  #
  ####################################

  # Update existing model
  update: (classname, changes) =>

    if classname is 'Setting'
      id = 1
      changes = @settingsValidate(changes)
    else
      id = changes.id

    # Check model exists on server
    if not @hasModel(classname, id)
      log "#{classname} doesn't exist on server"
      return
      # model = Default classname
      # for k, v of changes
      #   model[k] = v
      # changes = model

    # Set timestamp
    timestamps = data[2]
    if timestamps
      for attr, time of timestamps
        old = @time.get classname, id, attr
        if old > time
          delete timestamps[attr]
          delete changes[attr]
    else
      timestamps = {}
      now = Date.now()
      for k of changes
        continue if k is 'id'
        timestamps[k] = now

    @time.set classname, id, timestamps

    # Update list
    if classname is 'Task' and changes.list?
      oldTask = @findModel classname, id
      if oldTask.list isnt changes.list
        @taskMove id, oldTask.list, changes.list

    # Save to server
    model = @setModelAttributes classname, id, changes
    log "Updated #{ classname }: #{ model.name }"



  ########################################
  #    __   ___  __  ___  __   __        #
  #   |  \ |__  /__`  |  |__) /  \ \ /   #
  #   |__/ |___ .__/  |  |  \ \__/  |    #
  #                                      #
  ########################################

  # Delete existing model
  destroy: (classname, id, timestamp) =>
    model = @findModel classname, id

    # Check that the model hasn't been updated after this event
    timestamp ?= Date.now()
    return unless @time.check classname, id, timestamp

    # Destroy all tasks within that list
    if classname is 'List'
      for taskId in model.tasks
        log "Destroying Task #{ taskId }"
        # TODO: Prevent server from broadcasting these changes
        #       And make the client delete the tasks
        @destroy ['Task', taskId]

    # Remove from list
    else if classname is 'Task'
      @taskRemove id, model.list

    # Replace task with deleted template
    @setModel classname, id,
      id: id
      deleted: yes

    # Set timestamp
    @time.set classname, id, 'deleted', timestamp
    log "Destroyed #{ classname } #{ id }"


  # --------------------
  # Offline Sync Merging
  # --------------------

  # Sync
  sync: (queue, fn) =>
    log 'Running sync'

    # Map client IDs to server IDs -- for lists only
    client = {}

    for item, i in queue

      # TODO: Can't remember what this does.
      # I think it stops it from infinite looping.
      break if i >= 100

      [type, [classname, model], timestamp] = item

      ## Handles client list IDs ##

      # Example: You create a task in list 'c-10'
      # The list ID gets changed to 's-5' on the server
      # This code matches that list back to the task

      if type in ['create', 'update'] and
      classname is 'Task' and model.list.slice(0,2) is 'c-'

        # The list hasn't been assigned a server ID yet
        if client[model.list] is undefined

          # We have already checked this task
          if model._missing
            log 'We have a missing task!'
            i++
            continue

          else
            log "Moving Task #{model.id} in list #{model.list} to back of queue"
            model._missing = yes
            queue[queue.length] = queue[i]
            queue[i] = []
            i++
            continue

        else
          log "Found List ID #{ model.list } has changed to #{ client[model.list] }"
          model.list = client[model.list]
          delete model._missing

      switch type
        when 'create'
          oldId = model.id
          @create [classname, model, timestamp], (newId) ->
            if classname is 'List'
              log "Changing List #{ oldId } to #{ newId }"
              client[oldId] = newId

        when 'update'
          @update [classname, model, timestamp]

        when 'destroy'
          @destroy [classname, model, timestamp]

      i++

    fn [@exportModel('Task'), @exportModel('List')] if fn

  # Make sure data is in the right format
  parse: (event, data) ->
    return data


  # ----------
  # Task Order
  # ----------

  # Add a task to a list
  taskAdd: (taskId, listId) ->
    tasks = @findModel('List', listId).tasks
    return false unless tasks
    if tasks.indexOf(taskId) < 0
      tasks.push taskId
      @setModelAttributes 'List', listId, tasks:tasks

  # Remove a task from a list
  taskRemove: (taskId, listId) ->
    tasks = @findModel('List', listId).tasks
    return false unless tasks
    index = tasks.indexOf taskId
    if index > -1
      tasks.splice index, 1
      @setModelAttributes 'List', listId, tasks:tasks

  # Move a task from list to another
  taskMove: (taskId, oldListId, newListId) ->
    @taskAdd taskId, newListId
    @taskRemove taskId, oldListId

  # Replace a task ID
  taskUpdateId: (oldId, newId, listId) ->
    tasks = @findModel('List', listId).tasks
    index = tasks.indexOf oldId
    if index > -1
      tasks.spice index, 1, newId
      @setModelAttributes 'List', listId, tasks:tasks


  # -------------------
  # Settings Validation
  # -------------------

  settingsValidate: (settings) ->
    allowed = ['sort', 'weekStart', 'dateFormat', 'completedDuration',
               'confirmDelete', 'night', 'language', 'notifications',
               'notifyEmail', 'notifyTime', 'notifyRegular']
    out = {}
    for property in allowed
      if settings.hasOwnProperty(property)
        out[property] = settings[property]
    return out


  # --------------------
  # Miscellaneous events
  # --------------------

  ###*
   * Send a users list to an email address
   * @param {integer} uid: a user ID
   * @param {string} listId: a list ID
   * @param {string} email: an email address
   * @return {boolean} false: if error
  ###
  emailList: (data) ->
    return false unless Array.isArray(data)
    [uid, listId, email] = data
    require('./todo.html')(uid, listId)
      .then ([data, user]) ->
        listName = user.data('List')[listId]?.name
        options =
          to: email
          replyTo: user.email
          from: "#{ user.name } <hello@nitrotasks.com>"
          subject: "I've sent you my #{ listName } list"
          html: data
          generateTextFromHTML: true
        console.log options
        require('./mail').send(options)
      .fail (error) ->
        console.warn error

module.exports = Sync
