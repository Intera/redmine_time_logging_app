module.exports =
  # "open", "closed", "*", or "status_id"
  issueStatus: undefined
  issueClosedPastDays: redmineData.issues_closed_past_days || 7
  autocompleteMinLength: 3
  autocompleteLimit: 1000
  datepicker:
    firstDay: redmineData.datepicker.first_day || 1
    maxDate: redmineData.datepicker.max_date || "+7"
    minDate: redmineData.datepicker.min_date || "-6m"
    monthNamesShort: redmineData.datepicker.month_names_short || ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    monthNames: redmineData.datepicker.month_names || ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    dayNamesMin: redmineData.datepicker.day_names_min || ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    dayNamesShort: redmineData.datepicker.day_names_short || ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    dateFormat: redmineData.datepicker.date_format || "D y-m-d"
    closeText: redmineData.datepicker.close || "close"
    currentText: redmineData.datepicker.today || "today"
    prevText: redmineData.datepicker.prev || "previous"
    nextText: redmineData.datepicker.next || "next"
    showButtonPanel: true
    autoSize: true
  # in search results this separates projects and sub-projects
  issueNameDelimiter: " #{String.fromCharCode(187)} "
  path:
    images: "img/"
  autoReloadInterval: false
  requiredFields: ["project_id", "date", ["hours", "minutes"], "activity_id"]
  errorClass: "ui-state-error"
  redmine:
    translations: redmineData.translations
    urls: redmineData.backend_urls
    version_major: redmineData.redmine_version_major
    version_minor: redmineData.redmine_version_minor
