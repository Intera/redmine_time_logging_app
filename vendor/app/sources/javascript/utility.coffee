$$ = (->
  # like $, but caches results - use for elements that don't change after page load
  cache = {}
  (s) ->
    if cache.hasOwnProperty(s)
      $ cache[s]
    else
      e = jQuery(s)
      cache[s] = e  if e.length > 0
      e
)()

_.templateSettings = interpolate: /\{\{(.+?)\}\}/g

unless Array::every
  Array::every = (fun) ->
    len = @length
    throw new TypeError()  unless typeof fun is "function"
    thisp = arguments_[1]
    i = 0
    while i < len
      return false  if i of this and not fun.call(thisp, this[i], i, this)
      i++
    true

timeLimitedFunc = (func, wait) ->
  prev = 0
  next = undefined
  ->
    next = +new Date()
    if (next - prev) > wait
      prev = next
      func.apply this, arguments

# localisation + central string storage
translations = {}
translations["de"] =
  projectEditNotSupported: "Das nachträgliche Ändern des Projekts wird vom Ticket-System bisher nicht unterstützt (http://www.redmine.org/issues/588)."
  update: "Aktualisieren"
  create: "Erfassen"
  search: "Suche ..."
  activity: "Aktivität"
  unavailableProject: "Projekt nicht verfügbar"
  date: "Datum"
  comment: "Kommentar"
  confirmDelete: "Wirklich Löschen?"
  minutes: "Minuten"
  cancel: "Abbrechen"
  hours: "Stunden"
  yes: "Ja"
  no: "Nein"
  or: "oder"
  emptyForm: "Felder leeren"
  duplicate: "Einfügen"
  delete: "Löschen"
  issueOrProject: "Projekt oder Ticket"
  missingFields: "Fehlende Informationen"
  appName: "Zeiterfassung"
  success: "Erfolg"
  overview: "Übersicht"
  open_in_redmine: "Ausgewähltes Projekt oder Ticket anzeigen"
  loading: "Lade Daten"
  ticketMessage: "Ticketsystem meldet:\n"
  noTimeEntriesLoaded: "Keine Einträge gefunden"
  chooseActivity: "Aktivität auswählen ..."
  hours_header: "Stunden"
  activity_header: "Aktivität"
  project_task_header: "Projekt oder Aufgabe"
  reloadSearchData: "Suchdaten neu laden"
  dateNext: "Nächster Tag"
  datePrev: "Vorheriger Tag"
  edit: "Bearbeiten"
  error422Explanation: "Häufige Ursache: Versuch, Zeiteintrag auf ein Ticket umzubuchen das in einem anderen Projekt gespeichert ist."

translations["en"] =
  duplicate: "Insert"
  unavailableProject: "Project not available"
  projectEditNotSupported: "Changing the project is not supported by the ticket-system (http://www.redmine.org/issues/588)."
  search: "Search ..."
  delete: "Delete"
  update: "Update"
  create: "Create"
  activity: "Activity"
  date: "Date"
  yes: "Yes"
  no: "No"
  overview: "Overview"
  open_in_redmine: "View selected project or ticket"
  emptyForm: "Reset"
  cancel: "Cancel"
  appName: "Intera Time Tracking"
  comment: "Comment"
  confirmDelete: "Confirm delete"
  minutes: "Minutes"
  hours: "Hours"
  or: "or"
  issueOrProject: "Project or ticket"
  missingFields: "Missing fields"
  success: "Success"
  loading: "Loading"
  ticketMessage: "Ticketsystem says:\n"
  noTimeEntriesLoaded: "No entries found"
  chooseActivity: "Choose activity ..."
  hours_header: "Hours"
  activity_header: "Activity"
  project_task_header: "Project or task"
  reloadSearchData: "Reload search data"
  dateNext: "Next day"
  datePrev: "Previous day"
  edit: "Edit"

# get translation function
tl = (key) ->
  translations[window.displayLanguage]?[key] or key

getBrowserLanguage = ->
  # WebView on Android would always return "en" in navigator.*language, parse userAgent instead
  lang = lang[1] if navigator and
    navigator.userAgent and (lang = navigator.userAgent.match(/android.*\W(\w\w)-(\w\w)\W/i))
  if not lang and navigator
    if navigator.language
      lang = navigator.language
    else if navigator.browserLanguage
      lang = navigator.browserLanguage
    else if navigator.systemLanguage
      lang = navigator.systemLanguage
    else lang = navigator.userLanguage  if navigator.userLanguage
  lang.substr(0, 2)

getDisplayLanguage = ->
  if App.cache?.user_language
    t = App.cache.user_language
    if "en" == t then "en" else "de"
  else
    if getBrowserLanguage() == "de" then "de" else "en"

window.displayLanguage = getDisplayLanguage()

App.utility = (->
  isIssueID = (str) ->
    issueIDRegex.test str
  autocompleteMatchFunc = (searchstring) ->
    regex = undefined
    match = undefined
    if isIssueID(searchstring)
      #quicker search for issue ids
      regex = new RegExp(searchstring + "\\b")
      (item, index) -> regex.test item.value
    else
      matchCount = 0
      #search for words, not for special chars, in any order, case insensitive, keep one first and last whitespace
      regex = searchstring.replace(/[^a-zA-Z0-9üöä #]/g, "").split(" ")
      lastIsWhitespace = "" is regex[regex.length - 1]
      firstIsWhitespace = "" is regex[0]
      regex = _.filter regex, (e) -> e != ""
      if lastIsWhitespace then regex[regex.length - 1] += " "
      if firstIsWhitespace then regex[0] = " " + regex[0]
      #split into several regexp that must all match
      regex = _.map regex, (e) -> new RegExp(e, "i")
      (item, index) ->
        if matchCount >= App.config.autocompleteLimit
          false
        else
          matchOne = (regex) -> regex.test item.value
          if regex.every matchOne
            matchCount += 1
            true
          else
            false

  selectAll = ->
    @select()

  ignoreTicketIdRegexp = /#\d+/g

  sortByLocaleIgnoreTicketId = (a) ->
    a.sort (a, b) ->
      a.value.replace(ignoreTicketIdRegexp, "").localeCompare b.value.replace ignoreTicketIdRegexp, ""

  wrapDeferred = (func) ->
    (arg) ->
      func arg
      arg

  projectNameToID = (projects, name) ->
    keys = _.keys(projects)
    i = 0
    while i < keys.length
      return keys[i]  if projects[keys[i]].name is name
      i += 1
    false

  createProjectsIssuesAndSearchData = (projects, issues) ->
    searchData = []
    #convert redmine result arrays. {"projects": [project-data, ...]} -> {project-id: project-data, ...}
    #And fill searchData array
    projects = _.foldl(projects, (prev, ele) ->
      #insert projects into searchData
      searchData.push createProjectSearchDataEntry(ele)
      #insert into projects object
      prev[ele.id] = ele
      prev
    , {})
    issues = _.foldl(issues, (prev, ele) ->
      #insert into searchData
      searchData.push createIssueSearchDataEntry(ele, projects)
      prev[ele.id] = ele
      prev
    , {})
    [projects, issues, sortByLocaleIgnoreTicketId searchData]

  delim = App.config.issueNameDelimiter

  createProjectSearchDataEntry = (project) ->
    if project.parent
      label = "#{project.parent.name}#{delim}#{project.name}"
    else if project.parent_name
      label = "#{project.parent_name}#{delim}#{project.name}"
    else
      label = project.name
    label: label
    value: label

  createIssueSearchDataEntry = (issue, projects) ->
    project = projects[issue.project.id]
    issueString = "##{issue.id} #{issue.subject}"
    if issue.version then issueString = "#{issue.version}#{delim}#{issueString}"
    if project
      if project.parent_name
        label = "#{project.parent_name}#{delim}#{project.name}#{delim}#{issueString}"
      else
        label = "#{project.name}#{delim}#{issueString}"
    else
      label = issueString
    label: label
    value: label
    is_closed: issue.is_closed

  setSelectionRange = (element, selectionStart, selectionEnd) ->
    if element.setSelectionRange
      element.focus()
      element.setSelectionRange selectionStart, selectionEnd
    else if element.createTextRange
      range = element.createTextRange()
      range.collapse true
      range.moveEnd "character", selectionEnd
      range.moveStart "character", selectionStart
      range.select()

  setCursorPosition = (element, pos) ->
    setSelectionRange element, pos, pos

  padZeros = (number, totalLength) ->
    numberString = "" + number
    missingZeros = numberString.length % totalLength
    numberString = "0" + numberString  while missingZeros--
    numberString

  onKeypressRejectNaN = (event) ->
    #NaN is a number - this is why we don't use "isNumber"
    charCode = (if event.which then event.which else event.keyCode)
    #-> is numeric?
    #standard number keyrange || numpad number keyrange || tab || backspace || delete || lr arrows
    ((charCode > 47) and (charCode < 58)) or ((charCode > 95) and (charCode < 106)) or (charCode is 9) or (charCode is 8) or (charCode is 46) or (charCode is 37) or (charCode is 39)

  decimalHoursToHours = (arg) ->
    Math.floor Math.round(arg * 100) / 100

  decimalHoursToMinutes = (arg) ->
    res = Math.round((1 - (Math.ceil(arg) - arg)) * 60)
    (if 60 is res then 0 else res)

  decimalHoursToColonFormat = (arg) ->
    hours = decimalHoursToHours(arg)
    minutes = decimalHoursToMinutes(arg)
    res = ""
    res += hours  if hours
    res += ":" + padZeros(minutes, 2)  if minutes
    res

  mobileHideAddressBar = ->
    hideAddressBar = ->
      unless window.location.hash
        if document.height <= window.outerHeight + 10
          document.body.style.height = (window.outerHeight + 50) + "px"
          setTimeout (->
            window.scrollTo 0, 1
          ), 50
        else
          setTimeout (->
            window.scrollTo 0, 1
          ), 0
    window.addEventListener "load", hideAddressBar
    window.addEventListener "orientationchange", hideAddressBar

  issueIDToURL = (id) ->
    $config.baseURL + "issues/" + id

  missingFieldsError = (missingFields) ->
    _.map missingFields, (ele) ->
      if _.isArray(ele)
        missingFieldsError(ele).join " " + tl("or") + " "
      else
        $(fieldNameToSelector[ele]).addClass $config.errorClass
        fieldNameToDisplayName[ele]

  removeErrorClass = -> $(this).removeClass $config.errorClass

  copyDateObject = (date) ->
    new Date(date.getFullYear(), date.getMonth(), date.getDate(), date.getHours(), date.getMinutes())

  stringContains = (arg1, arg2) ->
    arg1.indexOf(arg2) >= 0

  $config = App.config
  issueIDRegex = new RegExp("^#\\d+$")

  fieldNameToSelector =
    activity_id: "#activity"
    comments: "#comments"
    hours: "#hours"
    minutes: "#minutes"
    project_id: "#search"

  fieldNameToDisplayName =
    activity_id: tl("activity")
    comments: tl("comments")
    datum: tl("date")
    hours: tl("hours")
    minutes: tl("minutes")
    project_id: tl("issueOrProject")

  defaultDialogConfig =
    buttons:
      "schließen": ->
        $(this).dialog "close"
    resizable: false
    closeOnEscape: true
    show: "fade"
    autoOpen: false

  displayDialog = undefined
  $ ->
    dialog = $("<div>").dialog(defaultDialogConfig)
    displayDialog = (message, title) ->
      if _.isString(message)
        dialog.html message
      else
        dialog.html ""
        dialog.append message
      dialog.dialog("option", "title", title).dialog "open"

  autocompleteMatchFunc: autocompleteMatchFunc
  copyDateObject: copyDateObject
  createProjectsIssuesAndSearchData: createProjectsIssuesAndSearchData
  createIssueSearchDataEntry: createIssueSearchDataEntry
  createProjectSearchDataEntry: createProjectSearchDataEntry
  decimalHoursToHours: decimalHoursToHours
  decimalHoursToMinutes: decimalHoursToMinutes
  decimalHoursToColonFormat: decimalHoursToColonFormat
  defaultDialogConfig: defaultDialogConfig
  fieldNameToDisplayName: fieldNameToDisplayName
  fieldNameToSelector: fieldNameToSelector
  isIssueID: isIssueID
  issueIDToURL: issueIDToURL
  missingFieldsError: missingFieldsError
  onKeypressRejectNaN: onKeypressRejectNaN
  projectNameToID: projectNameToID
  removeErrorClass: removeErrorClass
  selectAll: selectAll
  padZeros: padZeros
  stringContains: stringContains
  wrapDeferred: wrapDeferred
  mobileHideAddressBar: mobileHideAddressBar
  setSelectionRange: setSelectionRange
  setCursorPosition: setCursorPosition
  sortByLocaleIgnoreTicketId: sortByLocaleIgnoreTicketId
)()
