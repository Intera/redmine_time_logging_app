getBaseURL = ->
  location.protocol + "//" + location.host + "/"

datepickerConf =
  maxDate: "+0"
  minDate: "-6m"
  monthNamesShort: ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
  monthNames: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
  dayNamesMin: ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
  dayNamesShort: ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
  autoSize: true
  dateFormat: "D d.m.y"
  firstDay: 1
  showButtonPanel: true

App =
  debug: false
  cache:
    template: {}
  config:
    # open, closed, *, or status_id
    issueStatus: undefined
    issueClosedPastDays: 7
    autocompleteMinLength: 3
    autocompleteLimit: 1000
    datepicker: datepickerConf
    # in search results this separates projects and sub-projects
    issueNameDelimiter: " #{String.fromCharCode(187)} "
    path:
      images: "img/"
    autoReloadInterval: false
    baseURL: getBaseURL()
    requiredFields: ["project_id", "date", ["hours", "minutes"], "activity_id"]
    titleClass: "contentTitle"
    errorClass: "ui-state-error"
