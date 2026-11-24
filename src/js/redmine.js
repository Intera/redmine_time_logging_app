// Time Logging App - JavaScript source converted from CoffeeScript 2.7.0 output.
const timeLoggingAppRedmine = (function() {
  var config, createTimeEntry, defaultRedmineErrorHandler, deleteTimeEntry, getProjectsAndIssues, getRecent, getSpentTime, getTimeEntries, redmineConfig, translate, updateTimeEntry, urls;

  config = timeLoggingAppConfig;

  translate = function(key) {
    return config.redmine.translations[key] || key;
  };

  redmineConfig = config.redmine;

  urls = redmineConfig.urls;

  // functions for ajax calls between the app and the redmine backend interface.
  // all request functions return a jqXHR object.
  defaultRedmineErrorHandler = function(response, x, y) {
    var exc, message;
    if (0 === response.status) {

    // request aborted by the user
    } else if (404 === response.status) {
      return alert(translate("redmine_message") + translate("error_404_not_found") + `.\nrelevant url: \"${this.url}\"`);
    } else if (response.status !== 200) {
      try {
        message = translate("redmine_message") + " " + $.parseJSON(response.responseText).errors.join("\n");
      } catch (error) {
        exc = error;
        message = "http status " + response.status;
      }
      return alert(message);
    }
  };

  getTimeEntries = function(config) {
    if (config === undefined) {
      config = {};
    }
    if (config.spent_on instanceof Date) {
      config.spent_on = $.datepicker.formatDate("yy-mm-dd", config.spent_on);
    }
    return $.ajax({
      url: urls.time_entries,
      data: config
    });
  };

  getProjectsAndIssues = function(status, closedPastDays) {
    var data;
    data = {};
    data.closed_past_days = closedPastDays;
    if (status) {
      data.status = status;
    }
    return $.ajax({
      url: urls.projects_and_issues,
      data: data
    });
  };

  getRecent = function() {
    return $.ajax({
      url: urls.recent
    });
  };

  getSpentTime = function(project_id, issue_id) {
    return $.ajax({
      url: urls.spent_time,
      data: {
        project_id: project_id,
        issue_id: issue_id
      }
    });
  };

  createTimeEntry = function(data) {
    return $.ajax({
      type: "post",
      contentType: "application/json",
      data: JSON.stringify(data),
      url: urls.time_entries
    });
  };

  updateTimeEntry = function(id, data) {
    data.id = id;
    return $.ajax({
      type: "put",
      contentType: "application/json",
      data: JSON.stringify(data),
      url: urls.time_entries
    });
  };

  deleteTimeEntry = function(id) {
    return $.ajax({
      type: "delete",
      contentType: "application/json",
      data: JSON.stringify({id}),
      url: urls.time_entries
    });
  };

  $.ajaxSetup({
    dataType: "json",
    async: true,
    error: defaultRedmineErrorHandler,
    beforeSend: function(jqXHR, settings) {
      return this.url = settings.url;
    }
  });

  return {
    createTimeEntry: createTimeEntry,
    deleteTimeEntry: deleteTimeEntry,
    getProjectsAndIssues: getProjectsAndIssues,
    getRecent: getRecent,
    getSpentTime: getSpentTime,
    getTimeEntries: getTimeEntries,
    updateTimeEntry: updateTimeEntry
  };

})();
