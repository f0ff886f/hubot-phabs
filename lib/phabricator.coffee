# Description:
#   requests Phabricator Conduit api
#
# Dependencies:
#
# Configuration:
#  PHABRICATOR_URL
#  PHABRICATOR_API_KEY
#  PHABRICATOR_LISTS_INCOMING
#
# Author:
#   mose

querystring = require('querystring')

class Phabricator
  constructor: (@robot, env) ->
    @url = env.PHABRICATOR_URL
    @apikey = env.PHABRICATOR_API_KEY
    @bot_phid = env.PHABRICATOR_BOT_PHID

  ready: (msg) ->
    msg.send "Error: Phabricator url is not specified" if not @url
    msg.send "Error: Phabricator api key is not specified" if not @apikey
    return false unless (@url and @apikey)
    true

  withUser: (msg, user, cb) ->
    if @ready(msg) == true
      id = user.phid
      if id
        cb(id)
      else
        email = user.email_address || user.pagerdutyEmail
        unless email
          if msg.message.user.name == user.name
            msg.send "Sorry, I can't figure out your email address :( Can you tell me with `.phab me as you@yourdomain.com`?"
          else
            msg.send "Sorry, I can't figure #{user.name} email address. can you help me with .phab #{user.name} = <email>"
          return
        query = {
          "emails[0]": email,
          "api.token": @apikey
        }
        body = querystring.stringify(query)
        msg.http(@url)
          .path("api/user.query")
          .get(body) (err, res, payload) ->
            json_body = null
            switch res.statusCode
              when 200 then json_body = JSON.parse(payload)
              else
                console.log res.statusCode
                console.log payload
                json_body = { message: 'Fail' }
            unless json_body['result']
              msg.send "Sorry, I cannot find #{email} :("
              return
            user.phid = json_body['result']["0"]["phid"]
            cb user.phid


  taskInfo: (msg, id, cb) ->
    if @ready(msg) == true
      query = {
        "task_id": id,
        "api.token": @apikey
      }
      body = querystring.stringify(query)
      msg.http(@url)
        .path("api/maniphest.info")
        .get(body) (err, res, payload) ->
          json_body = null
          switch res.statusCode
            when 200 then json_body = JSON.parse(payload)
            else
              console.log res.statusCode
              console.log payload
              json_body = { message: 'Fail' }
          cb json_body

  fileInfo: (msg, id, cb) ->
    if @ready(msg) == true
      query = {
        "id": id,
        "api.token": @apikey
      }
      body = querystring.stringify(query)
      msg.http(@url)
        .path("api/file.info")
        .get(body) (err, res, payload) ->
          json_body = null
          switch res.statusCode
            when 200 then json_body = JSON.parse(payload)
            else
              console.log res.statusCode
              console.log payload
              json_body = { message: 'Fail' }
          cb json_body

  pasteInfo: (msg, id, cb) ->
    if @ready(msg) == true
      query = {
        "ids[0]": id,
        "api.token": @apikey
      }
      body = querystring.stringify(query)
      msg.http(@url)
        .path("api/paste.query")
        .get(body) (err, res, payload) ->
          json_body = null
          switch res.statusCode
            when 200 then json_body = JSON.parse(payload)
            else
              console.log res.statusCode
              console.log payload
              json_body = { message: 'Fail' }
          cb json_body

  createTask: (msg, phid, title, cb) ->
    if @ready(msg) == true
      url = @url
      apikey = @apikey
      bot_phid = @bot_phid
      @withUser msg, msg.message.user, (userPhid) ->
        query = {
          "transactions[0][type]": "title",
          "transactions[0][value]": "#{title}",
          "transactions[1][type]": "description",
          "transactions[1][value]": "(created by #{msg.message.user.name} on irc)",
          "transactions[2][type]": "subscribers.add",
          "transactions[2][value][0]": "#{userPhid}",
          "transactions[3][type]": "subscribers.remove",
          "transactions[3][value][0]": "#{bot_phid}",
          "api.token": apikey,
        }
        if phid.match /PHID-PROJ-/
          query["transactions[4][type]"] = "projects.add"
          query["transactions[4][value][]"] = "#{phid}"
        else
          query["transactions[4][type]"] = "column"
          query["transactions[4][value]"] = "#{phid}"

        body = querystring.stringify(query)
        msg.http(url)
          .path("api/maniphest.edit")
          .get(body) (err, res, payload) ->
            json_body = null
            switch res.statusCode
              when 200 then json_body = JSON.parse(payload)
              else
                console.log res.statusCode
                console.log payload
                json_body = JSON.parse(payload)
            cb json_body

  assignTask: (msg, tid, userphid, cb) ->
    if @ready(msg) == true
      query = {
        "objectIdentifier": "T#{tid}",
        "transactions[0][type]": "owner",
        "transactions[0][value]": "#{userphid}",
        "api.token": @apikey,
      }
      body = querystring.stringify(query)
      msg.http(@url)
        .path("api/maniphest.edit")
        .get(body) (err, res, payload) ->
          json_body = null
          switch res.statusCode
            when 200 then json_body = JSON.parse(payload)
            else
              console.log res.statusCode
              console.log payload
              json_body = { message: 'Fail' }
          cb json_body

  listTasks: (msg, projphid, cb) ->
    if @ready(msg) == true
      query = {
        "projectPHIDs[0]": "#{projphid}",
        "status": "status-open",
        "api.token": @apikey,
      }
      body = querystring.stringify(query)
      msg.http(@url)
        .path("api/maniphest.query")
        .get(body) (err, res, payload) ->
          json_body = null
          switch res.statusCode
            when 200 then json_body = JSON.parse(payload)
            else
              console.log res.statusCode
              console.log payload
              json_body = { message: 'Fail' }
          cb json_body

module.exports = Phabricator
