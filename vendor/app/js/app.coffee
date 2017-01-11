App.base = (->
  # depends on: the DOM being ready, redmine.coffee

  getCurrentUser = ->
    App.redmine.getCurrentUser().done (user) ->
      App.cache.user_id = user.user.id
      App.cache.user_language = user.user.language

  getIssuesProjectsAndSearchData = (status) ->
    # required variables in App.cache: searchData, projects, issues
    App.redmine.getProjectsAndIssues(status, App.config.issueClosedPastDays).done (projectsAndIssues) ->
      t = App.utility.createProjectsIssuesAndSearchData projectsAndIssues.projects, projectsAndIssues.issues
      App.cache.projects = t[0]
      App.cache.issues = t[1]
      App.cache.searchData = t[2]
      initAutocomplete t[0], t[1], t[2]
      App.redmine.getRecentTimeEntryObjects().done (recentTimeEntryObjects) ->
        App.cache.searchDataRecent = []
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
            App.cache.searchDataRecent.push App.utility.createIssueSearchDataEntry e, t[0]
          else
            e =
              id: e.project_id
              name: e.project_name
              parent_id: e.project_parent_id
              parent_name: e.project_parent_name
            App.cache.searchDataRecent.push App.utility.createProjectSearchDataEntry e
        App.cache.searchDataRecent = App.utility.sortByLocaleIgnoreTicketId App.cache.searchDataRecent

  getActivities = ->
    App.redmine.getActivities().done (_activities) ->
      selectEle = $$("#activity")
      App.cache.activities = {}
      _.each _activities.activities, (a) ->
        selectEle.append $("<option>").attr("value", a.id).html(a.name)
        App.cache.activities[a.id] = a.name

  sync = (formData) ->
    # create, delete or update a time entry
    apiData = formDataToAPIData formData
    if formData.timeEntryId
      App.redmine.updateTimeEntry formData.timeEntryId, apiData
    else
      App.redmine.createTimeEntry(apiData).done (timeEntry) ->
        timeEntry = timeEntry.time_entry
        issueOrProject = (timeEntry.issue and timeEntry.issue.id) or timeEntry.project.name
        issueOrProject = $("<a>").attr("href", App.utility.issueIDToURL(issueOrProject)).html("#" + issueOrProject)  if _.isNumber(issueOrProject)
        #console.log(t("success"), timeEntry.hours + " Stunden für ", issueOrProject, " erfasst.")
        emptyFormAfterSync()

  resetContentTitles = ->
    # should be a feature of int.contenttitle
    $$("#comments,#hours,#minutes,#search").each ->
      a = $(this)
      if a.val()
        a.removeClass App.config.titleClass
      else
        a.blur()
        a.addClass App.config.titleClass
    $$("#activity").change()

  emptyFormAfterSync = ->
    $("#comments,#hours,#minutes").val("").blur()
    $$("#search").prop "disabled", false

  emptyForm = ->
    # date and activity are not reset for usability
    $("#comments,#hours,#minutes,#search:not([disabled])").val("").blur()
    $$("input[type=text],textarea,select").each App.utility.removeErrorClass
    $$("button.open-in-redmine").hide()
    $$("#activity").val("").change()

  reloadSearchData = ->
    getIssuesProjectsAndSearchData App.config.issueStatus
    $$(document).trigger "timeEntriesReload"

  getSearchFormData = (str) ->
    str = $$("#search").val() unless str
    # user may have edited the search value
    return false unless str and _.some(App.cache.searchData, ((e) -> e.value == str))
    issueID = str.match(/#\d+/)
    if issueID
      issueID = parseInt(issueID[0].substring(1))
      issue_id: issueID
      project_id: parseInt(App.cache.issues[issueID].project.id)
    else
      # check if it is a parent- or sub-project
      projectName = _.last(str.split(App.config.issueNameDelimiter).map($.trim))
      project_id = parseInt(App.utility.projectNameToID(App.cache.projects, projectName))
      project_id: project_id  if project_id

  autocompleteSourceDefault = (req, handleResponse) ->
    # generates the autocomplete suggestions
    handleResponse _.filter(App.cache.searchData, App.utility.autocompleteMatchFunc(req.term))

  autocompleteSourceRecent = (req, handleResponse) ->
    handleResponse App.cache.searchDataRecent

  autocompleteFocus = (event, options) ->
    if !options or !options.onlyFocus
      if @.value == @.title
        # show latest entries
        $$("#search").autocomplete "option", "source", autocompleteSourceRecent
        $$("#search").autocomplete "option", "minLength", 0
        $$("#search").autocomplete "search", ""
      else
        $$("#search").autocomplete "search", $$("#search").val()

  openInRedmineUpdateURL = (searchValue) ->
    data = getSearchFormData searchValue
    if data
      if data.issue_id
        url = App.config.baseURL + "issues/" + data.issue_id
      else
        url = App.config.baseURL + "projects/" + data.project_id
      $$("button.open-in-redmine").data("href", url).show()
    else
      $$("button.open-in-redmine").hide()

  autocompleteSelect = (event, ui) -> openInRedmineUpdateURL ui.item.value
  autocompleteBlur = -> openInRedmineUpdateURL()
  autocompleteClick = ->
    @select()
    openInRedmineUpdateURL()

  initAutocomplete = (projects, issues, searchData, recentlyUpdatedSearchData) ->
    $$("#search").click(autocompleteClick).blur(autocompleteBlur).focus(autocompleteFocus).autocomplete
      select: autocompleteSelect
      minLength: App.config.autocompleteMinLength
      source: (req, handleResponse) ->
        # generates the autocomplete suggestions
        handleResponse _.filter(searchData, App.utility.autocompleteMatchFunc(req.term))
    .on "keydown", ->
      $$("#search").autocomplete "option", "minLength", App.config.autocompleteMinLength
      $$("#search").autocomplete "option", "source", autocompleteSourceDefault
    .data("ui-autocomplete")._renderItem = (ul, item) ->
      listItem = $("<li></li>").data("item.autocomplete", item).append("<a>" + item.label + "</a>").appendTo(ul)
      listItem.addClass "closed" if item.is_closed
      listItem

  formDataToAPIData = (formData) ->
    # direct mapping
    r = _.pick(formData, "activity_id", "comments", "hours", "project_id", "issue_id")
    # format changing
    r.spent_on = $.datepicker.formatDate("yy-mm-dd", formData.date)
    # convert hours and minutes to decimal hours
    r.hours = (r.hours or 0) + ((formData.minutes or 0) / 60)
    r

  onSubmit = ->
    formData = getFormData()
    if validate(formData)
      sync formData
    else
      false

  getFormData = ->
    formData = {}
    formData.comments = if $$("#comments").hasClass(App.config.titleClass) then "" else $$("#comments").val()
    formData.activity_id = parseInt($$("#activity").val())  unless $$("#activity").hasClass(App.config.titleClass)
    formData.date = $$("#date").datepicker("getDate")
    minutes = parseInt($$("#minutes").val())
    hours = parseInt($$("#hours").val())
    formData.minutes = minutes  if minutes
    formData.hours = hours  if hours
    _.extend formData, getSearchFormData()

  validateFieldExistence = (formData) ->
    formDataInclude = (a) ->
      _.has formData, a
    formDataIncludeExt = (a) ->
      if _.isArray(a)
        _.any a, formDataInclude
      else
        formDataInclude a
    missingFields = _.reject(App.config.requiredFields, formDataIncludeExt)
    $$("input[type=text],textarea,select").each App.utility.removeErrorClass
    if missingFields.length > 0
      $$("input[type=text],textarea,select").off("click", App.utility.removeErrorClass).one "click", App.utility.removeErrorClass
      App.utility.missingFieldsError(missingFields).join "<br/>"
      return false
    true

  validateOther = (formData) ->
    # insert additional validations here, or add functions to the array in "validate"
    true

  validate = (formData) ->
    results = [validateFieldExistence, validateOther].map((proc) ->
      proc formData
    )
    results.every _.identity

  loading = (state) ->
    if state or !state?
      _.delay (->
        true unless _isLoaded
      ), 1000
    else
      _isLoaded = true

  initDatepicker = ->
    $$("#date").datepicker App.config.datepicker
    $$("#date").datepicker "setDate", "+0"

  initAutoDataReload = ->
    return unless App.config.autoReloadInterval
    intervalAutoReload = (interval) ->
      clearInterval timer if timer
      timer = setInterval(->
        reloadSearchData()
      , interval)
    timer = undefined
    intervalAutoReload App.config.autoReloadInterval

  setTranslationTextAndTitle = (elements, key) ->
    t = tl key
    elements.attr("title", t).text t

  setTranslation = ->
    window.displayLanguage = getDisplayLanguage()
    setTranslationTextAndTitle $("button.delete"), "delete"
    setTranslationTextAndTitle $("button.duplicate"), "duplicate"
    setTranslationTextAndTitle $("button.cancel"), "cancel"
    setTranslationTextAndTitle $("button.submit"), "create"
    # titles will be used by .contentTitle
    $("#hours").attr "title", tl "hours"
    $("#minutes").attr "title",tl "minutes"
    $("#comments").attr "title", tl "comment"
    $("#search").attr "title", tl "search"
    $("#activity").attr "title", tl "chooseActivity"
    $("h2").text tl "appName"
    $("button.overview").attr "title", tl "overview"
    $("button.open-in-redmine").attr "title", tl "open_in_redmine"
    $("button.emptyForm").attr "title", tl "emptyForm"
    $(".reload-search-data").attr "title", tl "reloadSearchData"
    $(".dateControls .prev").attr "title", tl "datePrev"
    $(".dateControls .next").attr "title", tl "dateNext"
    $(".activity-header").html tl "activity_header"
    $(".project-task-header").html tl "project_task_header"
    $(".hours-header").html tl "hours_header"
    $("#search,#hours,#minutes,#comments,select").contentTitle()

  init = ->
    App.utility.mobileHideAddressBar()
    loading()
    r = $.when(App.redmine.init(), getCurrentUser().done(App.utility.wrapDeferred(initDatepicker)), getActivities(), getIssuesProjectsAndSearchData(App.config.issueStatus)).done(->
      $$("h2:first").show()
      $$("#form").show()
      loading(false)
      initAutoDataReload()
      $$("#search").trigger("focus", {onlyFocus: true}).select()
      setTranslation()
    )
    $("button").button()
    $("button.next").button("option", "icons", {
      primary: "ui-icon-circle-arrow-e"
    })
    $("button.prev").button("option", "icons", {
      primary: "ui-icon-circle-arrow-w"
    })
    $("button.reload-search-data").button("option", "icons", {
      primary: "ui-icon-arrowrefresh-1-e"
    })
    .click reloadSearchData
    $("button.emptyForm").button("option", "icons", {
      primary: "ui-icon-cancel"
    })
    $("button.overview").button("option", "icons", {
      primary: "ui-icon-note"
    }).click ->
      window.open $(@).data("href"), "_newtab"
    $$("button.open-in-redmine").hide().button("option", "icons", {
      primary: "ui-icon-extlink"
    }).click ->
      url = $(@).data("href")
      if url then window.open url, "_blank"
    $("#hours,#minutes").keydown App.utility.onKeypressRejectNaN
    $(".submit").click -> App.base.onSubmit()
    $(".emptyForm").click emptyForm
    openInRedmineUpdateURL()
    r

  sync = timeLimitedFunc sync, 1250
  _isLoaded = false

  init: init
  onSubmit: onSubmit
  loading: loading
  emptyForm: emptyForm
  getFormData: getFormData
  formDataToAPIData: formDataToAPIData
  resetContentTitles: resetContentTitles
  validate: validate
  sync: sync
)()
