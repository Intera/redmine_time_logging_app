config = require "./config"

$$ = (->
  # like $, but caches results. for elements that dont change after page load
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
  # only actually call the wrapped function when at least "wait" seconds have passed since the last actual call.
  prev = 0
  next = undefined
  ->
    next = +new Date()
    if (next - prev) > wait
      prev = next
      func.apply this, arguments

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

stringContains = (a, b) -> a.indexOf(b) >= 0
stringContainsEvery = (a, values) -> values.every (b) -> stringContains a, b

autocompleteMatchFunc = (searchstring) ->
  # searches for words, not for special chars, in any order, case insensitive, keep one leading and one trailing whitespace.
  # also search for the case insensitive search string as is.
  matchCount = 0
  patterns = searchstring.split(" ")
  lastIsWhitespace = "" is patterns[patterns.length - 1]
  firstIsWhitespace = "" is patterns[0]
  patterns = _.filter patterns, (e) -> e != ""
  patterns = patterns.map (a) -> a.toLowerCase()
  # keep a leading and trailing whitespace because if a user enters it they might want to search with it
  if lastIsWhitespace then patterns[patterns.length - 1] += " "
  if firstIsWhitespace then patterns[0] = " " + patterns[0]
  (item, index) ->
    if matchCount >= config.autocompleteLimit
      false
    else
      value = item.value.toLowerCase()
      if stringContainsEvery(value, patterns) or stringContains(value, searchstring)
        matchCount += 1
        true
      else
        false

selectAll = -> @select()
ignoreTicketIdRegexp = /#\d+/g

sortByLocaleIgnoreTicketId = (a) ->
  a.sort (a, b) ->
    a.value.replace(ignoreTicketIdRegexp, "").localeCompare b.value.replace ignoreTicketIdRegexp, ""

wrapDeferred = (func) ->
  (arg) ->
    func arg
    arg

projectNameToId = (projects, name) ->
  keys = _.keys(projects)
  i = 0
  while i < keys.length
    return keys[i]  if projects[keys[i]].name is name
    i += 1
  false

createProjectsIssuesAndSearchData = (projects, issues) ->
  # convert redmine result arrays. {"projects": [project-data, ...]} -> {project-id: project-data, ...}
  # and fill searchData array.
  searchData = []
  projects = _.foldl(projects, (prev, a) ->
    # insert projects into searchData
    searchData.push createProjectSearchDataEntry a unless redmineData.only_issues
    # insert into projects object
    prev[a.id] = a
    prev
  , {})
  issues = _.foldl(issues, (prev, a) ->
    # insert into searchData
    searchData.push createIssueSearchDataEntry a, projects
    prev[a.id] = a
    prev
  , {})
  [projects, issues, sortByLocaleIgnoreTicketId searchData]

delim = config.issueNameDelimiter

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

falseIfNaN = (a) -> if isNaN a then false else a

onKeypressRejectNaN = (event) ->
  # NaN is a number - this is why we don't use "isNumber"
  charCode = (if event.which then event.which else event.keyCode)
  # -> is numeric?
  # standard number keyrange || numpad number keyrange || tab || backspace || delete || lr arrows
  ((charCode > 47) and (charCode < 58)) or ((charCode > 95) and (charCode < 106)) or (charCode is 9) or (charCode is 8) or (charCode is 46) or (charCode is 37) or (charCode is 39)

decimalHoursToHoursAndMinutes = (a) ->
  hours = Math.floor a
  minutes = Math.round a * 60 % 60
  if 60 is minutes then [hours + 1, 0] else [hours, minutes]

decimalHoursToColonFormat = (a) ->
  [hours, minutes] = decimalHoursToHoursAndMinutes a
  res = ""
  res += hours if hours
  res += ":" + padZeros(minutes, 2) if minutes
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

issueIdToUrl = (id) ->
  config.redmine.urls.issues_redmine + "/" + id

removeErrorClass = -> $(this).removeClass config.errorClass

copyDateObject = (date) ->
  new Date(date.getFullYear(), date.getMonth(), date.getDate(), date.getHours(), date.getMinutes())

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
  dialog = $("<div>").dialog defaultDialogConfig
  displayDialog = (message, title) ->
    if _.isString(message)
      dialog.html message
    else
      dialog.html ""
      dialog.append message
    dialog.dialog("option", "title", title).dialog "open"

entityMap =
  "&": "&amp;"
  "<": "&lt;"
  ">": "&gt;"
  "\"": "&quot;"
  "'": "&#39;"
  "/": "&#x2F;"

escapeHtml = (string) ->
  String(string).replace /[&<>"'\/]/g, (s) ->
    entityMap[s]

roundFloat = (a) -> parseFloat(a.toPrecision(2))

module.exports =
  $$: $$
  autocompleteMatchFunc: autocompleteMatchFunc
  copyDateObject: copyDateObject
  createProjectsIssuesAndSearchData: createProjectsIssuesAndSearchData
  createIssueSearchDataEntry: createIssueSearchDataEntry
  createProjectSearchDataEntry: createProjectSearchDataEntry
  decimalHoursToHoursAndMinutes: decimalHoursToHoursAndMinutes
  decimalHoursToColonFormat: decimalHoursToColonFormat
  defaultDialogConfig: defaultDialogConfig
  escapeHtml: escapeHtml
  falseIfNaN: falseIfNaN
  issueIdToUrl: issueIdToUrl
  onKeypressRejectNaN: onKeypressRejectNaN
  projectNameToId: projectNameToId
  removeErrorClass: removeErrorClass
  selectAll: selectAll
  padZeros: padZeros
  roundFloat: roundFloat
  stringContains: stringContains
  wrapDeferred: wrapDeferred
  mobileHideAddressBar: mobileHideAddressBar
  setSelectionRange: setSelectionRange
  setCursorPosition: setCursorPosition
  sortByLocaleIgnoreTicketId: sortByLocaleIgnoreTicketId
  timeLimitedFunc: timeLimitedFunc
