module.exports =
  # "open", "closed", "*", or "status_id"
  issueStatus: undefined
  issueClosedPastDays: redmineData.issues_closed_past_days || 7
  autocompleteMinLength: 3
  autocompleteLimit: 1000
  datepicker:
    firstDay: redmineData.datepicker.first_day || 1
    maxDate: redmineData.datepicker.max_date || "+0"
    minDate: redmineData.datepicker.min_date || "-6m"
    monthNamesShort: redmineData.datepicker.month_names_short || ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
    monthNames: redmineData.datepicker.month_names || ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    dayNamesMin: redmineData.datepicker.day_names_min || ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
    dayNamesShort: redmineData.datepicker.day_names_short || ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
    dateFormat: redmineData.datepicker.date_format || "D y-m-d"
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
