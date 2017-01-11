#abstracts the ajax calls between app and redmine REST-API.
#all requesting functions return a jqXHR object
App.redmine = (->

  #important, otherwise "internal server error"s occur
  addCsrfTokenFunc = (token) ->
    (options, origOptions, request) ->
      request.setRequestHeader "X-CSRF-Token", token  if options.type.match(/(post)|(put)|(delete)/i)

  init = ->
    #sets up the csrf token. necessary for rails applications using "protect_from_forgery"
    $.ajax(
      url: appConfig.baseURL + csrfTokenPath
      dataType: "html"
    ).done (token) ->
      $.ajaxPrefilter addCsrfTokenFunc(token)

  defaultRedmineErrorHandler = (response, x, y) ->
    console.log response
    if 0 is response.status
      #request aborted (by the user)
      return
    else if 404 is response.status
      alert tl("ticketMessage") + "Eintrag nicht gefunden"
    else unless response.status is 200
      message = tl("ticketMessage") + $.parseJSON(response.responseText).errors.join("\n")
      if 422 is response.status
        message += "\n\n" + tl("error422Explanation")
      alert message

  deleteTimeEntry = (id) ->
    $.ajax
      type: "delete"
      dataType: "html"
      url: appConfig.baseURL + timeEntryPath + "/" + id + ".json"

  getCurrentUser = ->
    $.ajax url: appConfig.baseURL + userPath

  getTimeEntries = (config) ->
    config = {}  if _.isUndefined(config)
    config.spent_on = $.datepicker.formatDate("yy-mm-dd", config.spent_on)  if _.isDate(config.spent_on)
    $.ajax
      url: appConfig.baseURL + timeEntryPathRead
      data: config

  getProjects = ->
    $.ajax url: appConfig.baseURL + projectPath

  getIssues = (status) ->
    status = "*"  if _.isUndefined(status)
    $.ajax
      url: appConfig.baseURL + issuePath
      data:
        status: status

  getActivities = ->
    $.ajax url: appConfig.baseURL + activityPath

  getProjectsAndIssues = (status, closedPastDays) ->
    data = {}
    data.closed_past_days = closedPastDays
    data.status = status  if status
    $.ajax
      url: appConfig.baseURL + projectAndIssuesPath
      data: data

  getRecentTimeEntryObjects = ->
    $.ajax
      url: appConfig.baseURL + recentTimeEntryObjectsPath

  createTimeEntry = (data) ->
    $.ajax
      type: "post"
      contentType: "application/json"
      data: JSON.stringify(time_entry: data)
      url: appConfig.baseURL + timeEntryPath + ".json"

  updateTimeEntry = (id, data) ->
    $.ajax
      type: "put"
      contentType: "application/json"
      #important: does not return json data - if json would be specified here, an error handler would be called with "200 OK" parsererror
      dataType: "html"
      data: JSON.stringify(time_entry: data)
      url: appConfig.baseURL + timeEntryPath + "/" + id + ".json"

  appConfig = App.config
  issuePath = "time_logging_app/issues"
  userPath = "time_logging_app/current_user"
  csrfTokenPath = "time_logging_app/get_csrf_token"
  projectPath = "time_logging_app/projects"
  projectAndIssuesPath = "time_logging_app/projects_and_issues"
  activityPath = "time_logging_app/activities"
  recentTimeEntryObjectsPath = "time_logging_app/recent_time_entry_objects"
  timeEntryPathRead = "time_logging_app/time_entries"
  timeEntryPath = "/time_entries"

  $.ajaxSetup
    dataType: "json"
    async: true
    error: defaultRedmineErrorHandler

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
)()
