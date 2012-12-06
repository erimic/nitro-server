// Generated by CoffeeScript 1.4.0
(function() {
  var app, io, port, server, storage;

  port = process.env.PORT || 8080;

  app = require('express')();

  server = require('http').createServer(app);

  io = require('socket.io').listen(server);

  server.listen(port);

  console.log(port);

  io.configure(function() {
    io.set("log level", 1);
    io.set("transports", ["xhr-polling"]);
    return io.set("polling duration", 10);
  });

  storage = {
    "username": {
      data: {
        Settings: [
          {
            "sort": true,
            "id": "c-0"
          }
        ],
        List: [
          {
            "name": "Hfiiywrst",
            "id": "c-0"
          }
        ],
        Task: [
          {
            "name": "# low That is awesome",
            "completed": false,
            "priority": 1,
            "list": "inbox",
            "id": "c-0"
          }, {
            "name": "#medium",
            "completed": false,
            "priority": 2,
            "list": "c-0",
            "id": "c-2"
          }, {
            "name": "#high",
            "completed": false,
            "priority": 3,
            "list": "c-0",
            "id": "c-4"
          }, {
            "name": "Just a test",
            "completed": false,
            "priority": 1,
            "list": "inbox",
            "id": "c-3"
          }
        ]
      }
    }
  };

  io.sockets.on('connection', function(socket) {
    var user;
    user = null;
    socket.on('fetch', function(data, fn) {
      var model, uname;
      uname = data[0], model = data[1];
      if (uname in storage) {
        user = storage[uname];
        return fn(user.data[model]);
      }
    });
    socket.on('create', function(data) {
      var item, model;
      model = data[0], item = data[1];
      console.log(model);
      switch (model) {
        case "Task":
          user.data.Task.push(item);
          break;
        case "list":
          user.data.List.push(item);
      }
      console.log(item.name);
      return socket.broadcast.emit('create', [model, item]);
    });
    socket.on('update', function(data) {
      var index, item, model, task, _i, _len, _ref;
      model = data[0], item = data[1];
      switch (model) {
        case "Task":
          _ref = user.data.Task;
          for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
            task = _ref[index];
            if (task.id === item.id) {
              break;
            }
          }
          user.data.Task[index] = item;
      }
      console.log("Updated: " + item.name);
      return socket.broadcast.emit('update', [model, item]);
    });
    return socket.on('destroy', function(data) {
      var id, index, model, task, _i, _len, _ref;
      model = data[0], id = data[1];
      switch (model) {
        case "Task":
          _ref = user.data.Task;
          for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
            task = _ref[index];
            if (task.id === id) {
              break;
            }
          }
          user.data.Task.splice(index, 1);
      }
      console.log("Item " + id + " has been destroyed");
      return socket.broadcast.emit('destroy', [model, id]);
    });
  });

}).call(this);
