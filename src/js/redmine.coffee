config = require "./config"
translate = (key) -> config.redmine.translations[key] or key
redmineConfig = config.redmine
urls = redmineConfig.urls

# functions for ajax calls between the app and the redmine backend interface.
# all request functions return a jqXHR object.

defaultRedmineErrorHandler = (response, x, y) ->
  if 0 is response.status
    # request aborted by the user
    return
  else if 404 is response.status
    alert translate("redmine_message") + translate("error_404_not_found") + ".\nrelevant url: \"#{@url}\""
  else unless response.status is 200
    try message = translate("redmine_message") + " " + $.parseJSON(response.responseText).errors.join("\n")
    catch exc then message = "http status " + response.status
    alert message

getTimeEntries = (config) ->
  config = {}  if _.isUndefined(config)
  config.spent_on = $.datepicker.formatDate("yy-mm-dd", config.spent_on)  if _.isDate(config.spent_on)
  $.ajax
    url: urls.time_entries
    data: config

getProjectsAndIssues = (status, closedPastDays) ->
  data = {}
  data.closed_past_days = closedPastDays
  data.status = status  if status
  $.ajax
    url: urls.projects_and_issues
    data: data

getRecent = ->
  $.ajax
    url: urls.recent

getSpentTime = (project_id, issue_id) ->
  $.ajax
    url: urls.spent_time
    data:
      project_id: project_id
      issue_id: issue_id

createTimeEntry = (data) ->
  $.ajax
    type: "post"
    contentType: "application/json"
    data: JSON.stringify(data)
    url: urls.time_entries

updateTimeEntry = (id, data) ->
  data.id = id
  $.ajax
    type: "put"
    contentType: "application/json"
    data: JSON.stringify(data)
    url: urls.time_entries

deleteTimeEntry = (id) ->
  $.ajax
    type: "delete"
    contentType: "application/json"
    data: JSON.stringify({id})
    url: urls.time_entries

$.ajaxSetup
  dataType: "json"
  async: true
  error: defaultRedmineErrorHandler
  beforeSend: (jqXHR, settings) -> @url = settings.url

module.exports =
  createTimeEntry: createTimeEntry
  deleteTimeEntry: deleteTimeEntry
  getProjectsAndIssues: getProjectsAndIssues
  getRecent: getRecent
  getSpentTime: getSpentTime
  getTimeEntries: getTimeEntries
  updateTimeEntry: updateTimeEntry
