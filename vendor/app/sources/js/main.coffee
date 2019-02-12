# the app is initialised with "app.init()"

helper = require "./helper"
redmine = require "./redmine"
app_config = require "./config"
debug = false
cache = {template: {}}
_isLoaded = false
sync = helper.timeLimitedFunc sync, 1250
translate = (key) -> app_config.redmine.translations[key] or key

missingFieldsError = (missingFields) ->
  _.map missingFields, (a) ->
    if _.isArray(a)
      missingFieldsError(a).join " " + translate("or") + " "
    else
      $(fieldNameToSelector[a]).addClass app_config.errorClass
      fieldNameToDisplayName[a]

fieldNameToSelector =
  activity_id: "#activity"
  comments: "#comments"
  hours: "#hours"
  minutes: "#minutes"
  project_id: "#search"

fieldNameToDisplayName =
  activity_id: translate "activity"
  comments: translate "comments"
  datum: translate "date"
  hours: translate "hours"
  minutes: translate "minutes"
  project_id: translate "issueOrProject"

getIssuesProjectsAndSearchData = (status) ->
  redmine.getProjectsAndIssues(status, app_config.issueClosedPastDays).done (projectsAndIssues) ->
    t = helper.createProjectsIssuesAndSearchData projectsAndIssues.projects, projectsAndIssues.issues
    cache.projects = t[0]
    cache.issues = t[1]
    cache.searchData = t[2]
    initAutocomplete t[0], t[1], t[2]
    redmine.getRecent().done (recentTimeEntryObjects) ->
      cache.searchDataRecent = []
      recentTimeEntryObjects.forEach (e, index) ->
        if e.issue_id
          e =
            id: e.issue_id
            subject: e.issue_subject
            project_id: e.project_id
            version: e.version_name
            is_closed: e.issue_is_closed == 1
            project:
              name: e.project_name
              id: e.project_id
          cache.searchDataRecent.push helper.createIssueSearchDataEntry e, t[0]
        else
          e =
            id: e.project_id
            name: e.project_name
            parent_id: e.project_parent_id
            parent_name: e.project_parent_name
          cache.searchDataRecent.push helper.createProjectSearchDataEntry e

sync = (formData) ->
  # create, delete or update a time entry
  apiData = formDataToAPIData formData
  if formData.timeEntryId
    redmine.updateTimeEntry formData.timeEntryId, apiData
  else
    redmine.createTimeEntry(apiData).done (timeEntry) ->
      timeEntry = timeEntry.time_entry
      issueOrProject = (timeEntry.issue and timeEntry.issue.id) or timeEntry.project.name
      issueOrProject = $("<a>").attr("href", helper.issueIdToUrl(issueOrProject)).html("#" + issueOrProject)  if _.isNumber(issueOrProject)
      resetFormAfterSync()

resetFormAfterSync = ->
  $("#comments,#hours,#minutes").val("").blur()
  helper.$$("#search").prop "disabled", false

resetForm = ->
  # date and activity are not reset for workflow reasons
  $("#comments,#hours,#minutes,#search:not([disabled])").val("").blur()
  helper.$$("input[type=text],textarea,select").each helper.removeErrorClass
  helper.$$("button.open-in-redmine").hide()
  helper.$$("#activity").val("").change()

resetFormButton = ->
  if $("#wrapper").hasClass "editMode"
    resetFormAfterSync()
  else
    resetForm()

reloadSearchData = ->
  getIssuesProjectsAndSearchData app_config.issueStatus
  helper.$$(document).trigger "timeEntriesReload"

getSearchFormData = (str) ->
  # get metadata for a valid search input string with existing project and ticket.
  # use search input value if str is false
  str = helper.$$("#search").val() unless str
  # user may have edited the search value
  return false unless str and _.some(cache.searchData, ((b) -> b.value == str))
  issueId = str.match(/#\d+/)
  if issueId
    issueId = parseInt(issueId[0].substring(1))
    issue = cache.issues[issueId]
    issue: issue
    issue_id: issueId
    project_id: parseInt issue.project.id
  else
    # check if it is a parent- or sub-project
    projectName = _.last(str.split(app_config.issueNameDelimiter).map($.trim))
    project_id = parseInt(helper.projectNameToId(cache.projects, projectName))
    project_id: project_id if project_id

autocompleteSourceDefault = (req, handleResponse) ->
  # generates autocomplete suggestions
  handleResponse _.filter(cache.searchData, helper.autocompleteMatchFunc(req.term))

autocompleteSourceRecent = (req, handleResponse) ->
  handleResponse cache.searchDataRecent

autocompleteFocus = (event, options) ->
  if !options or !options.onlyFocus
    if @.value == @.title
      # show recently used entries
      helper.$$("#search").autocomplete "option", "source", autocompleteSourceRecent
      helper.$$("#search").autocomplete "option", "minLength", 0
      helper.$$("#search").autocomplete "search", ""
    else
      helper.$$("#search").autocomplete "search", helper.$$("#search").val()

openInRedmineUpdateURL = (searchValue) ->
  data = getSearchFormData searchValue
  if data
    if data.issue_id
      url = app_config.redmine.urls.issues_redmine + "/" + data.issue_id
    else
      url = app_config.redmine.urls.projects_redmine + "/" + data.project_id
    helper.$$("button.open-in-redmine").data("href", url).show()
  else
    helper.$$("button.open-in-redmine").hide()

autocompleteSelect = (event, ui) -> openInRedmineUpdateURL ui.item.value
autocompleteBlur = -> openInRedmineUpdateURL()

autocompleteClick = ->
  @select()
  openInRedmineUpdateURL()

initAutocomplete = (projects, issues, searchData, recentlyUpdatedSearchData) ->
  helper.$$("#search").click(autocompleteClick).blur(autocompleteBlur).focus(autocompleteFocus).autocomplete
    select: autocompleteSelect
    minLength: app_config.autocompleteMinLength
    source: (req, handleResponse) ->
      # generates/filters autocomplete suggestions
      handleResponse _.filter(searchData, helper.autocompleteMatchFunc(req.term))
  .on "keydown", ->
    helper.$$("#search").autocomplete "option", "minLength", app_config.autocompleteMinLength
    helper.$$("#search").autocomplete "option", "source", autocompleteSourceDefault
  .data("ui-autocomplete")._renderItem = (ul, item) ->
    listItem = $("<li></li>").data("item.autocomplete", item).append("<a>" + item.label + "</a>").appendTo(ul)
    listItem.addClass "closed" if item.is_closed
    listItem

formDataToAPIData = (formData) ->
  # taken as is
  r = _.pick(formData, "activity_id", "comments", "hours", "project_id", "issue_id")
  # format change necessary
  r.spent_on = $.datepicker.formatDate("yy-mm-dd", formData.date)
  # convert hours and minutes to decimal hours
  r.hours = (r.hours or 0) + ((formData.minutes or 0) / 60)
  r

getFormData = ->
  formData = {}
  formData.comments = helper.$$("#comments").val()
  formData.activity_id = parseInt helper.$$("#activity").val()
  formData.date = helper.$$("#date").datepicker("getDate")
  minutes = parseInt helper.$$("#minutes").val()
  hours = parseInt helper.$$("#hours").val()
  formData.minutes = minutes if minutes
  formData.hours = hours if hours
  if activeTimeEntryId
    formData.timeEntryId = activeTimeEntryId
    formData.activeTimeEntry = cache.timeEntries[activeTimeEntryId]
  _.extend formData, getSearchFormData()

validateFieldExistence = (formData) ->
  formDataContainsOne = (a) -> _.has formData, a
  formDataContains = (a) ->
    if _.isArray(a) then _.any a, formDataContainsOne
    else formDataContainsOne a
  missingFields = _.reject(app_config.requiredFields, formDataContains)
  helper.$$("input[type=text],textarea,select").each helper.removeErrorClass
  if missingFields.length > 0
    helper.$$("input[type=text],textarea,select").off("click", helper.removeErrorClass).one "click", helper.removeErrorClass
    missingFieldsError(missingFields).join "<br/>"
    return false
  true

validateOther = (formData) ->
  # insert additional validations here, or add functions to the array in "validate".
  if redmineData.overbooking_warning
    # warn when overbooking for the first time
    new_hours = (formData.hours or 0) + ((formData.minutes or 0) / 60)
    if formData.new then old_hours = 0
    else old_hours = formData.activeTimeEntry.hours
    if formData.issue and formData.activeTimeEntry.issue
      estimated = formData.issue.estimated_hours
      total_spent = formData.activeTimeEntry.issue.spent_hours
      if ((not (old_hours is new_hours)) and (estimated > total_spent) and (estimated < new_hours + total_spent))
        return confirm translate("overbooking_warning")
  true

validate = (formData) ->
  # object -> boolean
  validators = [validateFieldExistence, validateOther]
  results = validators.map((f) -> f formData)
  # true if all elements are true
  results.every _.identity

loading = (state) ->
  if state or !state?
    _.delay (->
      true unless _isLoaded
    ), 1000
  else
    _isLoaded = true

initAutoDataReload = ->
  return unless app_config.autoReloadInterval
  intervalAutoReload = (interval) ->
    clearInterval timer if timer
    timer = setInterval(->
      reloadSearchData()
    , interval)
  timer = undefined
  intervalAutoReload app_config.autoReloadInterval

confirmDialog = null
activeTimeEntryId = null
prevTimeEntry = null

initDeleteDialog = ->
  config = {buttons: {}}
  config.buttons[translate "no"] = -> $(this).dialog "close"
  config.buttons[translate "yes"] = ->
    $(@).dialog "close"
    deleteTimeEntry activeTimeEntryId
  config = _.defaults(config, helper.defaultDialogConfig)
  confirmDialog = $("<div>").dialog config

timeFormat = (hours, minutes) ->
  r = []
  r.push hours + " Stunden"  if hours
  r.push minutes + " Minuten"  if minutes
  r.join " "

confirmDelete = ->
  hours = helper.$$("#hours").val()
  minutes = helper.$$("#minutes").val()
  message = timeFormat(hours, minutes) + "<br/><br/>\"" + helper.$$("#search").val() + "\""
  confirmDialog.html(message).dialog("option", "title", translate("confirmDelete")).dialog "open"

updateTimeEntry = ->
  formData = getFormData()
  formData.new = false
  if validate(formData)
    sync(formData).done (response) ->
      exitEditMode()
      helper.$$(document).trigger "timeEntriesReload", "inplace"

createTimeEntry = ->
  formData = getFormData()
  formData.new = true
  if formData.issue_id
    redmine.getSpentTime(formData.project_id, formData.issue_id).done (response) ->
      formData.activeTimeEntry =
        issue:
          spent_hours: response["total"]
      if validate(formData)
        sync(formData).done (response) ->
          helper.$$(document).trigger "timeEntriesReload", "inplace"
  else
    # validateOther does not need spent time for projects
    if validate(formData)
      sync(formData).done (response) ->
        helper.$$(document).trigger "timeEntriesReload", "inplace"

getDisplayFormData = ->
  # gets the form data in a format that can be easily reinserted
  r = timeEntryReceiveToSendFormat(formDataToAPIData(getFormData()))
  r.project.name = helper.$$("#search").val()  if r.project
  r

displayFormDataToDom = (formData) -> timeEntryToDOM formData

startEditMode = (timeEntryId) ->
  throw ("missing timeEntryId") unless timeEntryId
  $("#timeEntries .active").removeClass("active")
  $("#timeEntries [data-entry-id=#{timeEntryId}]").addClass("active")
  $("#wrapper").addClass "editMode"
  if activeTimeEntryId
    activeTimeEntryId = timeEntryId
    timeEntryToDOM cache.timeEntries[timeEntryId]
    return
  prevTimeEntry = getDisplayFormData()
  activeTimeEntryId = timeEntryId
  helper.$$(".delete, .cancel").show()
  helper.$$(".delete").on "click", confirmDelete
  helper.$$("button.submit").addClass("update").html(translate("update")).off("click").on "click", updateTimeEntry
  helper.$$("button.cancel").one "click", exitEditMode
  $(document).on "keyup.time_logging_app", (event) ->
    if "Escape" is event.key then exitEditMode()
  timeEntryToDOM cache.timeEntries[timeEntryId]

exitEditMode = ->
  activeTimeEntryId = false
  $(document).off "keyup.time_logging_app"
  helper.$$(".delete,.cancel").off "click"
  helper.$$(".delete,.cancel").hide()
  helper.$$("button.submit").removeClass("update").html(translate("create")).off("click").click createTimeEntry
  displayFormDataToDom prevTimeEntry
  $("#timeEntries .active").removeClass("active")
  $("#wrapper").removeClass "editMode"
  helper.$$(".resetForm").show()
  prevTimeEntry = false

deleteTimeEntry = (id) ->
  redmine.deleteTimeEntry(id).done ->
    exitEditMode()
    helper.$$(document).trigger "timeEntriesReload", "inplace"
    resetForm()

createTimeEntriesUrl = (timeEntry) ->
  major = app_config.redmine.version_major
  minor = app_config.redmine.version_minor
  if major > 3 or (major is 3 and minor >= 4)
    result = app_config.redmine.urls.projects_redmine + "/" + timeEntry.project.id + "/time_entries"
    if timeEntry.issue?.id? then result + "?issue_id=~" + timeEntry.issue.id else result
  else
    if timeEntry.issue?.id?
      app_config.redmine.urls.issues_redmine + "/" + timeEntry.issue.id + "/time_entries";
    else
      app_config.redmine.urls.projects_redmine + "/" + timeEntry.project.id + "/time_entries";

timeEntryToTableRow = (a, even) ->
  classes = [(if even then "even" else "odd")]
  if a.issue
    name = helper.createIssueSearchDataEntry cache.issues[a.issue.id], cache.projects
    name = name.value if name
    projectOrIssueUrl = app_config.redmine.urls.issues_redmine + "/" + a.issue.id
  else
    # is project
    projectOrIssueUrl = app_config.redmine.urls.projects_redmine + "/" + a.project.id
    project = cache.projects[a.project.id]
    if project
      name = helper.createProjectSearchDataEntry project
      name = name.value if name
    else
      console.warn "project not available, id \"#{a.project.id}\""
      classes.push "unavailable-project"
      name = translate "unavailableProject"
  time = helper.decimalHoursToColonFormat(a.hours)
  # get spent hours
  spent_hours = a.issue?.spent_hours || a.project.spent_hours
  if isNaN spent_hours then spent_hours = 0
  else
    # round value to nearest hour unless smaller than one hour
    spent_hours = if spent_hours >= 1 then Math.round spent_hours else helper.decimalHoursToColonFormat spent_hours
  # get estimated hours
  estimated_hours = a.issue?.estimated_hours || a.project.estimated_hours
  if isNaN estimated_hours then estimated_hours = 0
  else
    estimated_hours = if estimated_hours >= 1 then Math.round estimated_hours else helper.decimalHoursToColonFormat estimated_hours
  estimates = spent_hours + (if estimated_hours then "/" + estimated_hours else "")
  if estimated_hours
    if spent_hours >= estimated_hours then classes.push "overbooked"
    else if spent_hours / estimated_hours >= 0.8 then classes.push "almost-overbooked"
  # create html
  cache.template.timeEntry
    entry_id: a.id
    time: time
    estimates: estimates
    name: name
    comments: (if a.comments then helper.escapeHtml(a.comments) else "")
    activity: cache.activities[a.activity.id]
    projectOrIssueUrl: projectOrIssueUrl
    timeEntriesUrl: createTimeEntriesUrl(a)
    classes: classes.join(" ")

insertTimeEntryRows = (timeEntries) ->
  targetEle = helper.$$("#timeEntries tbody")
  _.each timeEntries, (a, index) ->
    even = (index % 2) is 0
    if a.issue and not cache.issues[a.issue.id]
      # is a time entry of an issue that has not been loaded while getting issues (for example an old closed issue or a new issue).
      # we handle it by using the loaded time entry information
      cache.issues[a.issue.id] = a.issue
      val = timeEntryToSearchDataEntry(a)
      cache.searchData.push val
    targetEle.append timeEntryToTableRow(a, even)

insertTimeEntryAsNew = (timeEntryId) ->
  throw ("missing timeEntryId") unless timeEntryId
  timeEntryToDOM cache.timeEntries[timeEntryId]

displayTimeEntries = (timeEntries, config) ->
  helper.$$("#timeEntries tbody").children().remove()
  if timeEntries.length
    # timeEntries in the format as retrieved from the backend interface
    daySpentTime = _.foldl(timeEntries, ((result, a) -> result + a.hours), 0)
    helper.$$(".daySpentTime").html helper.decimalHoursToColonFormat(daySpentTime)
    insertTimeEntryRows timeEntries
    $(".timeEntry .edit").button(icons:
      primary: "ui-icon-pencil"
    ).click ->
      timeEntryId = parseInt($(this).parents(".timeEntry:first").data("entry-id"))
      startEditMode timeEntryId
    .attr("title", translate "edit")
    if config and config.animation is "inplace"
      # jquery highlight effect was not working
      helper.$$("#timeEntries").show()
    else
      helper.$$("#timeEntries").effect "slide",
        direction: "up"
      , 220
    $(".timeEntry .insert").button(icons:
      primary: "ui-icon-arrowthickstop-1-n"
    ).click ->
      timeEntryId = parseInt($(this).parents(".timeEntry:first").data("entry-id"))
      insertTimeEntryAsNew timeEntryId
    .attr("title", translate "duplicate")
  else
    helper.$$("#timeEntries").hide()

cacheTimeEntries = (apiTimeEntries) ->
  cache.timeEntries = {}
  _.each apiTimeEntries, (a) ->
    cache.timeEntries[a.id] = a

getTimeEntries = (data, config, noEntriesFound) ->
  throw "getTimeEntries - user_id is not set"  if _.isUndefined(cache.user_id)
  if not config or not config.animation
    helper.$$("#timeEntries").hide()
    loading()
  redmine.getTimeEntries(data).done((response) ->
    timeEntries = response.time_entries
    cacheTimeEntries response.time_entries
    displayTimeEntries response.time_entries, config
  ).always (response) ->
    helper.$$("#loading .icon").hide()
    if response.time_entries and (response.time_entries.length is 0)
      helper.$$("#loading .text").html translate("noTimeEntriesLoaded") if (not noEntriesFound) or (not noEntriesFound())
    else
      loading(false)

timeEntryToSearchDataEntry = (a) ->
  if a.issue
    a.issue = _.extend(a.issue, cache.issues[a.issue.id])
    a.issue.project = id: a.project.id
    helper.createIssueSearchDataEntry a.issue, cache.projects
  else helper.createProjectSearchDataEntry cache.projects[a.project.id] if a.project

hasReceiveFormat = (a) ->
  a and _.isObject(a) and a.hours and a.spent_on and (not a.activity or a.activity.id) and (not a.project or a.project.id) and (not a.issue or a.issue.id)

timeEntryReceiveToSendFormat = (a) ->
  console.warn "timeEntryReceiveToSendFormat - wrong type for argument", a  if debug and not hasReceiveFormat(a)
  # redmines post- and get-formats for time entries differ. see below for differing keys
  receiveFormat = _.pick(a, "hours", "comments", "spent_on")
  receiveFormat.activity = id: a.activity_id  if a.activity_id
  receiveFormat.issue = id: a.issue_id  if a.issue_id
  receiveFormat.project = id: a.project_id  if a.project_id
  receiveFormat

timeEntryToDOM = (timeEntry) ->
  # insert time entry data into form fields.
  # in the format as received from the backend interface
  [hours, minutes] = helper.decimalHoursToHoursAndMinutes timeEntry.hours
  helper.$$("#hours").val (if hours and (0 isnt hours) then hours else "")
  helper.$$("#minutes").val (if minutes and (0 isnt minutes) then minutes else "")
  val = timeEntry.comments
  helper.$$("#comments").val (if val then val else "")
  val = timeEntry.activity and timeEntry.activity.id
  helper.$$("#activity").val (if val then val else "")
  val = timeEntryToSearchDataEntry(timeEntry)
  helper.$$("#search").val(if val then val.value else "")
  helper.$$("#search").blur()
  helper.$$("input[type=text],textarea,select").each helper.removeErrorClass

cancelEdit = ->
  resetFields()
  stopEditMode()

extendBase = ->
  baseCreateTimeEntry = createTimeEntry
  createTimeEntry = ->
    r = baseCreateTimeEntry()
    if r then r.done -> helper.$$(document).trigger "timeEntriesReload", "inplace"
    else r

dateIsWeekend = (date) ->
  (date.getDay() is 6) or (date.getDay() is 0)

datepickerChangeDays = (element, difference) ->
  prevDate = element.datepicker("getDate")
  nextDate = helper.copyDateObject(prevDate)
  nextDate.setDate prevDate.getDate() + difference
  element.datepicker "setDate", nextDate
  newDate = element.datepicker("getDate")
  if (prevDate.getFullYear() isnt newDate.getFullYear()) or (prevDate.getMonth() isnt newDate.getMonth()) or (prevDate.getDate() isnt newDate.getDate())
    datepickerUpdate ->
      datepickerChangeDays helper.$$("#date"), Math.min(difference, 1)  if dateIsWeekend(nextDate)

incrementDate = -> datepickerChangeDays helper.$$("#date"), 1
decrementDate = -> datepickerChangeDays helper.$$("#date"), -1

onTimeEntriesReload = (event, animation) ->
  config = if animation then {animation: animation} else undefined
  getTimeEntries
    spent_on: helper.$$("#date").datepicker("getDate")
  , config

initialise = ->
  helper.mobileHideAddressBar()
  loading()
  # activities
  selectEle = helper.$$("#activity")
  cache.activities = {}
  _.each redmineData.activities, (a) ->
    selectEle.append $("<option>").attr("value", a.id).html(a.name)
    cache.activities[a.id] = a.name
  # current user
  user = redmineData.user
  cache.user_id = user.id
  lang = user.language
  cache.user_language = lang
  # csrf token. important, otherwise "internal server error"s occur
  token = redmineData.csrf_token
  $.ajaxPrefilter (options, origOptions, request) ->
    request.setRequestHeader "X-CSRF-Token", token  if options.type.match(/(post)|(put)|(delete)/i)
  # datepicker
  helper.$$("#date").datepicker app_config.datepicker
  helper.$$("#date").datepicker "setDate", "+0"
  # buttons and fields
  $("button").button()
  $("button.next").button("option", "icons", {
    primary: "ui-icon-circle-arrow-e"
  })
  $("button.prev").button("option", "icons", {
    primary: "ui-icon-circle-arrow-w"
  })
  $("button.resetForm").button("option", "icons", {
    primary: "ui-icon-cancel"
  })
  $("button.overview").button("option", "icons", {
    primary: "ui-icon-note"
  }).click ->
    window.open $(@).data("href"), "_newtab"
  helper.$$("button.open-in-redmine").hide().button("option", "icons", {
    primary: "ui-icon-extlink"
  }).click ->
    url = $(@).data("href")
    if url then window.open url, "_blank"
  $("#hours,#minutes").keydown helper.onKeypressRejectNaN
  $(".submit").click -> createTimeEntry()
  $(".resetForm").click resetFormButton
  openInRedmineUpdateURL()
  # search field
  getIssuesProjectsAndSearchData(app_config.issueStatus).done ->
    helper.$$("h2:first").show()
    helper.$$("#form").show()
    loading(false)
    initAutoDataReload()
    helper.$$("#search").trigger("focus", {onlyFocus: true}).select()
    # editing
    cache.template.timeEntry = _.template($("#timeEntryTemplate").text())
    extendBase()
    initDeleteDialog()
    onTimeEntriesReload()
    helper.$$(document).on "timeEntriesReload", onTimeEntriesReload
    helper.$$("#date").datepicker "option", "onSelect", datepickerUpdate
    $(".dateControls .prev").click decrementDate
    $(".dateControls .next").click incrementDate
    window.dispatchEvent new CustomEvent("timeEntryEditing")
    $("#wrapper").show()

setDate = (date) ->
  helper.$$("#date").datepicker "setDate", date
  datepickerUpdate()

timeEntriesLoadingDelayed = _.throttle(->
  date = helper.$$("#date").datepicker("getDate")
  getTimeEntries spent_on: date
, 2000)

datepickerUpdate = (->
  request = undefined
  (noEntriesFound) ->
    if request and (request.state() is "pending")
      request.abort()
      request = false
    date = helper.$$("#date").datepicker("getDate")
    request = getTimeEntries(
      spent_on: date
    , false, noEntriesFound)
)()

module.exports =
  config: app_config
  initialise: initialise
