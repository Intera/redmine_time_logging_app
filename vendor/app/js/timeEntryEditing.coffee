App.timeEntryEditing = (->

  App.confirmDialog
  App.timeEntryId
  App.prevTimeEntry

  initDeleteDialog = ->
    config = {buttons: {}}
    config.buttons[tl "no"] = -> $(this).dialog "close"
    config.buttons[tl "yes"] = ->
      $(@).dialog "close"
      deleteTimeEntry App.timeEntryId
    config = _.defaults(config, App.utility.defaultDialogConfig)
    App.confirmDialog = $("<div>").dialog config

  timeFormat = (hours, minutes) ->
    r = []
    r.push hours + " Stunden"  if hours
    r.push minutes + " Minuten"  if minutes
    r.join " "

  confirmDelete = ->
    hours = (if $$("#hours").hasClass(App.config.titleClass) then `undefined` else $$("#hours").val())
    minutes = (if $$("#minutes").hasClass(App.config.titleClass) then `undefined` else $$("#minutes").val())
    message = timeFormat(hours, minutes) + "<br/><br/>\"" + $$("#search").val() + "\""
    App.confirmDialog.html(message).dialog("option", "title", tl("confirmDelete")).dialog "open"

  updateTimeEntry = ->
    formData = App.base.getFormData()
    formData.timeEntryId = App.timeEntryId
    if App.base.validate(formData)
      App.base.sync(formData).done (response) ->
        exitEditMode()
        $$(document).trigger "timeEntriesReload", "inplace"

  getDisplayFormData = ->
    #gets the form data in a format that can be easily reinserted.
    r = timeEntryReceiveToSendFormat(App.base.formDataToAPIData(App.base.getFormData()))
    r.project.name = $$("#search").val()  if r.project
    r

  displayFormDataToDom = (formData) ->
    timeEntryToDOM formData

  startEditMode = (timeEntryId) ->
    throw ("missing timeEntryId") unless timeEntryId
    $("#timeEntries .active").removeClass("active")
    $("#timeEntries [data-entry-id=#{timeEntryId}]").addClass("active")
    $("#wrapper").addClass "editMode"
    if App.timeEntryId
      #update edit mode
      App.timeEntryId = timeEntryId
      timeEntryToDOM App.cache.timeEntries[timeEntryId]
      return
    App.prevTimeEntry = getDisplayFormData()
    App.timeEntryId = timeEntryId
    $$(".delete,.cancel").show()
    $$(".delete").on "click", confirmDelete
    $$("button.submit").addClass("update").html(tl("update")).off("click").one "click", updateTimeEntry
    $$("button.cancel").one "click", exitEditMode
    $$(".emptyForm").hide()
    timeEntryToDOM App.cache.timeEntries[timeEntryId]

  exitEditMode = ->
    App.timeEntryId = false
    $$(".delete,.cancel").off "click"
    $$(".delete,.cancel").hide()
    $$("button.submit").removeClass("update").html(tl("create")).off("click").click App.base.onSubmit
    displayFormDataToDom App.prevTimeEntry
    $("#timeEntries .active").removeClass("active")
    $("#wrapper").removeClass "editMode"
    $$("#search").trigger("focus", {onlyFocus: true}) if $$("#search").hasClass(App.config.titleClass)
    $$(".emptyForm").show()
    App.prevTimeEntry = false

  deleteTimeEntry = (id) ->
    App.redmine.deleteTimeEntry(id).done ->
      exitEditMode()
      $$(document).trigger "timeEntriesReload", "inplace"
      App.base.emptyForm()

  createTimeEntriesUrl = (timeEntry) ->
    r = App.config.baseURL
    if timeEntry.issue?.id?
      r += "issues/" + timeEntry.issue.id
    else
      r += "projects/" + timeEntry.project.id
    r + "/time_entries"

  timeEntryToTableRow = (a, even) ->
    if a.issue
      name = App.utility.createIssueSearchDataEntry App.cache.issues[a.issue.id], App.cache.projects
      name = name.value if name
      projectOrIssueUrl = App.config.baseURL + "issues/" + a.issue.id
    else
      projectOrIssueUrl = App.config.baseURL + "projects/" + a.project.id
      project = App.cache.projects[a.project.id]
      if project
        name = App.utility.createProjectSearchDataEntry project
        name = name.value if name
      else
        console.warn "project not available, id \"#{a.project.id}\""
        classes = "unavailable-project"
        name = tl "unavailableProject"
    time = App.utility.decimalHoursToColonFormat(a.hours)
    spent_hours = a.issue?.spent_hours || a.project.spent_hours
    if isNaN spent_hours
      spent_hours = 0
    else
      spent_hours = if spent_hours >= 1 then Math.round spent_hours else App.utility.decimalHoursToColonFormat spent_hours
    estimated_hours = a.issue?.estimated_hours || a.project.estimated_hours
    if isNaN estimated_hours
      estimated_hours = 0
    else
      estimated_hours = if estimated_hours >= 1 then Math.round estimated_hours else App.utility.decimalHoursToColonFormat estimated_hours
    estimates = spent_hours + (if estimated_hours then "/" + estimated_hours else "")
    App.cache.template.timeEntry
      entry_id: a.id
      time: time
      estimates: estimates
      name: name
      comments: (if a.comments then App.utility.escapeHtml(a.comments) else "")
      activity: App.cache.activities[a.activity.id]
      projectOrIssueUrl: projectOrIssueUrl
      timeEntriesUrl: createTimeEntriesUrl(a)
      classes: (if even then "even" else "odd") + (if classes then " " + classes else "")

  insertTimeEntryRows = (timeEntries) ->
    targetEle = $$("#timeEntries tbody")
    _.each timeEntries, (ele, index) ->
      even = (index % 2) is 0
      if ele.issue and not App.cache.issues[ele.issue.id]
        #time entry of issue that has not been loaded while getting issues (for example closed issue, new issue).
        # we can handle it, and use only the available time entry information
        App.cache.issues[ele.issue.id] = ele.issue
        val = timeEntryToSearchDataEntry(ele)
        App.cache.searchData.push val
      targetEle.append timeEntryToTableRow(ele, even)

  insertTimeEntryAsNew = (timeEntryId) ->
    throw ("missing timeEntryId") unless timeEntryId
    timeEntryToDOM App.cache.timeEntries[timeEntryId]

  displayTimeEntries = (timeEntries, config) ->
    $$("#timeEntries tbody").children().remove()
    if timeEntries.length
      #timeEntries in the format as retrieved from the REST API
      daySpentTime = _.foldl(timeEntries, (prev, ele) ->
        prev + ele.hours
      , 0)
      $$(".daySpentTime").html App.utility.decimalHoursToColonFormat(daySpentTime)
      insertTimeEntryRows timeEntries
      $(".timeEntry .edit").button(icons:
        primary: "ui-icon-pencil"
      ).click ->
        timeEntryId = parseInt($(this).parents(".timeEntry:first").data("entry-id"))
        startEditMode timeEntryId
      .attr("title", tl "edit")
      if config and config.animation is "inplace"
        #jquery highlight effect not working
        $$("#timeEntries").show()
      else
        $$("#timeEntries").effect "slide",
          direction: "up"
        , 220
      $(".timeEntry .insert").button(icons:
        primary: "ui-icon-arrowthickstop-1-n"
      ).click ->
        timeEntryId = parseInt($(this).parents(".timeEntry:first").data("entry-id"))
        insertTimeEntryAsNew timeEntryId
      .attr("title", tl "duplicate")
    else
      $$("#timeEntries").hide()

  cacheTimeEntries = (apiTimeEntries) ->
    App.cache.timeEntries = {}
    _.each apiTimeEntries, (ele) ->
      App.cache.timeEntries[ele.id] = ele

  getTimeEntries = (data, config, noEntriesFound) ->
    throw "getTimeEntries - user_id is not set"  if _.isUndefined(App.cache.user_id)
    if not config or not config.animation
      #sliding, hide and show
      $$("#timeEntries").hide()
      App.base.loading()
    App.redmine.getTimeEntries(data).done((response) ->
      timeEntries = response.time_entries
      cacheTimeEntries response.time_entries
      displayTimeEntries response.time_entries, config
    ).always (response) ->
      $$("#loading .icon").hide()
      if response.time_entries and (response.time_entries.length is 0)
        $$("#loading .text").html tl("noTimeEntriesLoaded")  if not noEntriesFound or not noEntriesFound()
      else
        App.base.loading(false)

  timeEntryToSearchDataEntry = (a) ->
    if a.issue
      a.issue = _.extend(a.issue, App.cache.issues[a.issue.id])
      a.issue.project = id: a.project.id
      App.utility.createIssueSearchDataEntry a.issue, App.cache.projects
    else App.utility.createProjectSearchDataEntry App.cache.projects[a.project.id] if a.project

  hasReceiveFormat = (a) ->
    a and _.isObject(a) and a.hours and a.spent_on and (not a.activity or a.activity.id) and (not a.project or a.project.id) and (not a.issue or a.issue.id)

  timeEntryReceiveToSendFormat = (a) ->
    console.warn "timeEntryReceiveToSendFormat - wrong type for argument", a  if App.debug and not hasReceiveFormat(a)
    # redmines post and get formats for time entries differ. see the if-blocks for differing keys
    receiveFormat = _.pick(a, "hours", "comments", "spent_on")
    receiveFormat.activity = id: a.activity_id  if a.activity_id
    receiveFormat.issue = id: a.issue_id  if a.issue_id
    receiveFormat.project = id: a.project_id  if a.project_id
    receiveFormat

  timeEntryToDOM = (timeEntry) ->
    # insert time entry data into form fields.
    # api-receive format
    val = undefined
    val = App.utility.decimalHoursToHours(timeEntry.hours)
    $$("#hours").val (if val and (0 isnt val) then val else "")
    val = App.utility.decimalHoursToMinutes(timeEntry.hours)
    $$("#minutes").val (if val and (0 isnt val) then val else "")
    val = timeEntry.comments
    $$("#comments").val (if val then val else "")
    val = timeEntry.activity and timeEntry.activity.id
    $$("#activity").val (if val then val else "")
    val = timeEntryToSearchDataEntry(timeEntry)
    $$("#search").val(if val then val.value else "")
    $$("#search").blur()
    App.base.resetContentTitles()
    $$("input[type=text],textarea,select").each App.utility.removeErrorClass

  cancelEdit = ->
    resetFields()
    stopEditMode()

  extendBase = ->
    baseOnSubmit = App.base.onSubmit
    App.base.onSubmit = ->
      r = baseOnSubmit()
      if r then r.done -> $$(document).trigger "timeEntriesReload", "inplace"
      else r

  dateIsWeekend = (date) ->
    (date.getDay() is 6) or (date.getDay() is 0)

  datepickerChangeDays = (element, difference) ->
    prevDate = element.datepicker("getDate")
    nextDate = App.utility.copyDateObject(prevDate)
    nextDate.setDate prevDate.getDate() + difference
    element.datepicker "setDate", nextDate
    newDate = element.datepicker("getDate")
    if (prevDate.getFullYear() isnt newDate.getFullYear()) or (prevDate.getMonth() isnt newDate.getMonth()) or (prevDate.getDate() isnt newDate.getDate())
      datepickerUpdate ->
        datepickerChangeDays $$("#date"), Math.min(difference, 1)  if dateIsWeekend(nextDate)

  incrementDate = ->
    datepickerChangeDays $$("#date"), 1

  decrementDate = ->
    datepickerChangeDays $$("#date"), -1

  onTimeEntriesReload = (event, animation) ->
    config = undefined
    config = animation: animation  if animation
    getTimeEntries
      spent_on: $$("#date").datepicker("getDate")
    , config

  init = ->
    $ ->
      App.cache.template.timeEntry = _.template($("#timeEntryTemplate").text())
      extendBase()
      initDeleteDialog()
      onTimeEntriesReload()
      $$(document).on "timeEntriesReload", onTimeEntriesReload
      $$("#date").datepicker "option", "onSelect", datepickerUpdate
      $(".dateControls .prev").click decrementDate
      $(".dateControls .next").click incrementDate
      window.dispatchEvent new CustomEvent("timeEntryEditing")
      $("#wrapper").show()

  setDate = (date) ->
    $$("#date").datepicker "setDate", date
    datepickerUpdate()

  timeEntriesLoadingDelayed = _.throttle(->
    date = $$("#date").datepicker("getDate")
    getTimeEntries spent_on: date
  , 2000)

  datepickerUpdate = (->
    request = undefined
    (noEntriesFound) ->
      if request and (request.state() is "pending")
        request.abort()
        request = false
      date = $$("#date").datepicker("getDate")
      request = getTimeEntries(
        spent_on: date
      , false, noEntriesFound)
  )()

  setDate: setDate
  init: init
  startEditMode: startEditMode
  exitEditMode: exitEditMode
)()
