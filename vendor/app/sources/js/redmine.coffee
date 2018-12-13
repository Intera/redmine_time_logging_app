config = require "./config"
redmineConfig = config.redmine
urls = redmineConfig.urls

# functions for ajax calls between the app and the redmine backend interface.
# all request functions return a jqXHR object.

# important, otherwise "internal server error"s occur
addCsrfTokenFunc = (token) ->
  (options, origOptions, request) ->
    request.setRequestHeader "X-CSRF-Token", token  if options.type.match(/(post)|(put)|(delete)/i)

init = ->
  # sets up the csrf token. necessary for rails applications using "protect_from_forgery" like redmine
  $.ajax(
    url: urls.get_csrf_token
    dataType: "html"
  ).done (token) ->
    $.ajaxPrefilter addCsrfTokenFunc(token)

jQuery.ajaxSetup
  beforeSend: (jqXHR, settings) ->
    @url = settings.url;

defaultRedmineErrorHandler = (response, x, y) ->
  if 0 is response.status
    # request aborted by the user
    return
  else if 404 is response.status
    alert tl("ticketMessage") + tl("error404NotFound") + ".\nrelevant url: \"#{@url}\""
  else unless response.status is 200
    message = tl("ticketMessage") + $.parseJSON(response.responseText).errors.join("\n")
    if 422 is response.status
      message += "\n\n" + tl("error422Explanation")
    alert message

deleteTimeEntry = (id) ->
  $.ajax
    type: "delete"
    dataType: "html"
    url: urls.time_entries_redmine + "/" + id + ".json"

getCurrentUser = ->
  $.ajax url: urls.current_user

getTimeEntries = (config) ->
  config = {}  if _.isUndefined(config)
  config.spent_on = $.datepicker.formatDate("yy-mm-dd", config.spent_on)  if _.isDate(config.spent_on)
  $.ajax
    url: urls.time_entries
    data: config

getProjects = ->
  $.ajax url: urls.projects

getIssues = (status) ->
  status = "*"  if _.isUndefined(status)
  $.ajax
    url: urls.issues
    data:
      status: status

getActivities = ->
  $.ajax url: urls.activities

getProjectsAndIssues = (status, closedPastDays) ->
  data = {}
  data.closed_past_days = closedPastDays
  data.status = status  if status
  $.ajax
    url: urls.projects_and_issues
    data: data

getRecentTimeEntryObjects = ->
  $.ajax
    url: urls.recent_time_entry_objects

createTimeEntry = (data) ->
  $.ajax
    type: "post"
    contentType: "application/json"
    data: JSON.stringify(time_entry: data)
    url: urls.time_entries_redmine + ".json"

updateTimeEntry = (id, data) ->
  $.ajax
    type: "put"
    contentType: "application/json"
    # important: does not return json data - if "json" would be written here, there would be a "200 OK" parsererror
    dataType: "html"
    data: JSON.stringify(time_entry: data)
    url: urls.time_entries_redmine + "/" + id + ".json"

$.ajaxSetup
  dataType: "json"
  async: true
  error: defaultRedmineErrorHandler

module.exports =
  getActivities: getActivities
  getTimeEntries: getTimeEntries
  getProjects: getProjects
  getIssues: getIssues
  getCurrentUser: getCurrentUser
  getRecentTimeEntryObjects: getRecentTimeEntryObjects
  deleteTimeEntry: deleteTimeEntry
  getProjectsAndIssues: getProjectsAndIssues
  createTimeEntry: createTimeEntry
  updateTimeEntry: updateTimeEntry
  init: init
