// Time Logging App - JavaScript source converted from CoffeeScript 2.7.0 output.
window.app = (function() {
  // the app is started with initialize()
  var _isLoaded, activeTimeEntryId, app_config, autocompleteChange, autocompleteClick, autocompleteFocus, autocompleteSelect, autocompleteSourceDefault, autocompleteSourceRecent, cache, cacheTimeEntries, confirmDelete, confirmDialog, createTimeEntriesUrl, createTimeEntry, dataAutoReload, dateIsWeekend, dateYmdEqual, datepickerChangeDays, datepickerUpdate, debug, decrementDate, deleteTimeEntry, displayFormDataToDom, displayTimeEntries, dom, exitEditMode, extendBase, fieldNameToDisplayName, fieldNameToSelector, fieldsError, formDataToAPIData, getDisplayFormData, getFormData, getIssuesProjectsAndSearchData, getSearchFormData, getTimeEntries, hasReceiveFormat, helper, hideActivityOption, hideNextDateButton, incrementDate, initAutocomplete, initDeleteDialog, initialize, initialize_dom_cache, insertTimeEntryAsNew, insertTimeEntryRows, loading, onTimeEntriesReload, openInRedmineUpdateURL, prevTimeEntry, redmine, reloadSearchData, resetForm, resetFormAfterSync, resetFormButton, setDate, startEditMode, sync, timeEntryReceiveToSendFormat, timeEntryToDom, timeEntryToSearchDataEntry, timeEntryToTableRow, timeFormat, timer, translate, updateActivities, updateTimeEntry, validate, validateFieldExistence, validateOther;

  helper = timeLoggingAppHelper;

  redmine = timeLoggingAppRedmine;

  app_config = timeLoggingAppConfig;

  debug = false;

  cache = {
    template: {},
    timeEntries: {}
  };

  dom = {};

  _isLoaded = false;

  sync = helper.timeLimitedFunc(sync, 1250);

  translate = function(key) {
    return app_config.redmine.translations[key] || key;
  };

  fieldsError = function(fields) {
    return fields.map(function(a) {
      if (Array.isArray(a)) {
        return fieldsError(a).join(" " + translate("general_text_or") + " ");
      } else {
        $(fieldNameToSelector[a]).addClass(app_config.errorClass);
        return fieldNameToDisplayName[a];
      }
    });
  };

  fieldNameToSelector = {
    activity_id: "#activity",
    comments: "#comments",
    hours: "#hours",
    minutes: "#minutes",
    project_id: "#search"
  };

  fieldNameToDisplayName = {
    activity_id: translate("field_activity"),
    comments: translate("label_comment"),
    datum: translate("label_date"),
    hours: translate("field_hours"),
    minutes: translate("field_minutes"),
    project_id: translate("issue_or_project")
  };

  getIssuesProjectsAndSearchData = function(status) {
    return redmine.getProjectsAndIssues(status, app_config.issueClosedPastDays).done(function(projectsAndIssues) {
      var t;
      t = helper.createProjectsIssuesAndSearchData(projectsAndIssues.projects, projectsAndIssues.issues);
      cache.projects = t[0];
      cache.issues = t[1];
      cache.searchData = t[2];
      initAutocomplete(t[0], t[1], t[2]);
      return redmine.getRecent().done(function(recentTimeEntryObjects) {
        cache.searchDataRecent = [];
        return recentTimeEntryObjects.forEach(function(a, index) {
          if (!cache.projects[a.project_id]) {
            return;
          }
          if (a.issue_id) {
            if (!cache.issues[a.issue_id]) {
              return;
            }
            a = {
              id: a.issue_id,
              subject: a.issue_subject,
              project_id: a.project_id,
              version: a.version_name,
              is_closed: a.issue_is_closed === 1,
              project: {
                id: a.project_id,
                name: a.project_name
              }
            };
            return cache.searchDataRecent.push(helper.createIssueSearchDataEntry(a, cache.projects));
          } else {
            a = {
              id: a.project_id,
              name: a.project_name,
              parent_id: a.project_parent_id,
              parent_name: a.project_parent_name
            };
            return cache.searchDataRecent.push(helper.createProjectSearchDataEntry(a));
          }
        });
      });
    });
  };

  sync = function(formData) {
    var apiData;
    // create, delete or update a time entry
    apiData = formDataToAPIData(formData);
    if (formData.timeEntryId) {
      return redmine.updateTimeEntry(formData.timeEntryId, apiData);
    } else {
      return redmine.createTimeEntry(apiData).done(function() {
        return resetFormAfterSync();
      });
    }
  };

  resetFormAfterSync = function() {
    $("#comments,#hours,#minutes").val("").blur();
    return helper.$$("#search").prop("disabled", false);
  };

  resetForm = function() {
    // date and activity are not reset for workflow reasons
    $("#comments,#hours,#minutes,#search:not([disabled])").val("").blur();
    helper.$$("input[type=text],textarea,select").each(helper.removeErrorClass);
    dom.openInRedmineButton.hide();
    return helper.$$("#activity").val("").change();
  };

  resetFormButton = function() {
    if ($("#wrapper").hasClass("editMode")) {
      return resetFormAfterSync();
    } else {
      return resetForm();
    }
  };

  reloadSearchData = function() {
    getIssuesProjectsAndSearchData(app_config.issueStatus);
    return helper.$$(document).trigger("timeEntriesReload");
  };

  getSearchFormData = function(str) {
    var issue, issueId, projectName, project_id;
    if (!str) {
      // get metadata for a valid search input string with existing project and ticket.
      // use search input value if str is false
      str = helper.$$("#search").val();
    }
    if (!(str && cache.searchData.some(function(b) {
      return b.value === str;
    }))) {
      // user may have edited the search value
      return false;
    }
    issueId = str.match(/#\d+/);
    if (issueId) {
      issueId = parseInt(issueId[0].substring(1));
      issue = cache.issues[issueId];
      return {
        issue: issue,
        issue_id: issueId,
        project_id: parseInt(issue.project.id)
      };
    } else {
      // check if it is a parent- or sub-project
      projectName = str.split(app_config.issueNameDelimiter).map($.trim).at(-1);
      project_id = parseInt(helper.projectNameToId(cache.projects, projectName));
      if (project_id) {
        return {
          project_id: project_id
        };
      }
    }
  };

  autocompleteSourceDefault = function(req, handleResponse) {
    // generates autocomplete suggestions
    return handleResponse(cache.searchData.filter(helper.autocompleteMatchFunc(req.term)));
  };

  autocompleteSourceRecent = function(req, handleResponse) {
    return handleResponse(cache.searchDataRecent);
  };

  autocompleteFocus = function(event, options) {
    if (!options || !options.onlyFocus) {
      if (this.value) {
        return helper.$$("#search").autocomplete("search", helper.$$("#search").val());
      } else {
        // show recently used entries
        helper.$$("#search").autocomplete("option", "source", autocompleteSourceRecent);
        helper.$$("#search").autocomplete("option", "minLength", 0);
        return helper.$$("#search").autocomplete("search", "");
      }
    }
  };

  openInRedmineUpdateURL = function(data) {
    var button, url;
    button = dom.openInRedmineButton.hide();
    if (!data) {
      return;
    }
    if (data.issue_id) {
      url = app_config.redmine.urls.issues_redmine + "/" + data.issue_id;
    } else {
      url = app_config.redmine.urls.projects_redmine + "/" + data.project_id;
    }
    return button.data("href", url).show();
  };

  hideActivityOption = function(id) {
    return helper.$$("#activity").find("option[value=" + id + "]").prop("disabled", true).hide();
  };

  updateActivities = function(project_id) {
    var options, selected;
    // hide/show project specific activities (project settings, time tracking).
    options = helper.$$("#activity option");
    options.prop("disabled", false).show();
    Object.entries(cache.activities).forEach(function([id, a]) {
      if (a.parent_id) {
        if (project_id === a.project_id) {
          hideActivityOption(a.parent_id);
          if (!a.active) {
            return hideActivityOption(id);
          }
        } else {
          return hideActivityOption(id);
        }
      } else {
        if (!a.active) {
          return hideActivityOption(id);
        }
      }
    });
    // select the first option if the selected option became hidden.
    // use :enabled because options never match :visible.
    selected = options.filter(":enabled:selected");
    if (!selected.length) {
      return options.filter(":enabled:first").prop("selected", true);
    }
  };

  autocompleteSelect = function(event, ui) {
    var data;
    data = getSearchFormData(ui.item.value);
    openInRedmineUpdateURL(data);
    return data && updateActivities(data.project_id);
  };

  autocompleteClick = function() {
    return this.select();
  };

  autocompleteChange = function(event, ui) {
    var data;
    if (ui.item) {
      data = getSearchFormData(ui.item.value);
    }
    return openInRedmineUpdateURL(data);
  };

  initAutocomplete = function(projects, issues, searchData, recentlyUpdatedSearchData) {
    return helper.$$("#search").click(autocompleteClick).focus(autocompleteFocus).autocomplete({
      select: autocompleteSelect,
      change: autocompleteChange,
      minLength: app_config.autocompleteMinLength,
      source: function(req, handleResponse) {
        // generates/filters autocomplete suggestions
        return handleResponse(searchData.filter(helper.autocompleteMatchFunc(req.term)));
      }
    }).on("keydown", function() {
      helper.$$("#search").autocomplete("option", "minLength", app_config.autocompleteMinLength);
      return helper.$$("#search").autocomplete("option", "source", autocompleteSourceDefault);
    }).data("ui-autocomplete")._renderItem = function(ul, item) {
      var listItem;
      listItem = $("<li></li>").data("item.autocomplete", item).append("<a>" + item.label + "</a>").appendTo(ul);
      if (item.is_closed) {
        listItem.addClass("closed");
      }
      return listItem;
    };
  };

  formDataToAPIData = function(formData) {
    var r;
    r = {
      activity_id: formData.activity_id,
      comments: formData.comments,
      hours: formData.hours,
      project_id: formData.project_id,
      issue_id: formData.issue_id
    };
    // format change necessary
    r.spent_on = $.datepicker.formatDate("yy-mm-dd", formData.date);
    // convert hours and minutes to decimal hours
    r.hours = (r.hours || 0) + ((formData.minutes || 0) / 60);
    return r;
  };

  getFormData = function() {
    var activity_id, formData, hours, minutes;
    formData = {};
    formData.comments = helper.$$("#comments").val();
    activity_id = helper.falseIfNaN(parseInt(helper.$$("#activity").val()));
    if (typeof activity_id === "number") {
      formData.activity_id = activity_id;
    }
    formData.date = helper.$$("#date").datepicker("getDate");
    minutes = helper.falseIfNaN(parseInt(helper.$$("#minutes").val()));
    hours = helper.falseIfNaN(parseInt(helper.$$("#hours").val()));
    if (typeof minutes === "number") {
      formData.minutes = minutes;
    }
    if (typeof hours === "number") {
      formData.hours = hours;
    }
    if (activeTimeEntryId) {
      formData.timeEntryId = activeTimeEntryId;
      formData.activeTimeEntry = cache.timeEntries[activeTimeEntryId];
    }
    return Object.assign(formData, getSearchFormData());
  };

  validateFieldExistence = function(formData) {
    var formDataContains, formDataContainsOne, missingFields;
    formDataContainsOne = function(a) {
      return Object.hasOwn(formData, a);
    };
    formDataContains = function(a) {
      if (Array.isArray(a)) {
        return a.some(formDataContainsOne);
      } else {
        return formDataContainsOne(a);
      }
    };
    missingFields = app_config.requiredFields.filter(function(a) {
      return !formDataContains(a);
    });
    helper.$$("input,textarea,select").each(helper.removeErrorClass);
    if (missingFields.length > 0) {
      helper.$$("input,textarea,select").off("click", helper.removeErrorClass).one("click", helper.removeErrorClass);
      fieldsError(missingFields).join("<br/>");
      return false;
    }
    return true;
  };

  validateOther = function(formData) {
    var estimated, new_hours, old_hours, total_spent;
    // insert additional validations here, or add functions to the validators array in "validate".
    if (!(0 < ((formData.hours || 0) + (formData.minutes || 0)))) {
      fieldsError(["hours", "minutes"]);
      return false;
    }
    if (redmineData.overbooking_warning) {
      // warn when overbooking for the first time
      new_hours = (formData.hours || 0) + ((formData.minutes || 0) / 60);
      if (formData.new) {
        old_hours = 0;
      } else {
        old_hours = formData.activeTimeEntry.hours;
      }
      if (formData.issue && formData.activeTimeEntry.issue) {
        estimated = formData.issue.estimated_hours;
        if (!estimated) {
          return true;
        }
        total_spent = formData.activeTimeEntry.issue.spent_hours - old_hours;
        if ((!(old_hours === new_hours)) && (estimated > total_spent) && (estimated < new_hours + total_spent)) {
          return confirm(translate("overbooking_warning"));
        }
      }
    }
    return true;
  };

  validate = function(formData) {
    var results, validators;
    // object -> boolean
    validators = [validateFieldExistence, validateOther];
    results = validators.map(function(f) {
      return f(formData);
    });
    // true if all elements are true
    return results.every(function(result) {
      return result;
    });
  };

  loading = function(state) {
    if (state || (state == null)) {
      return setTimeout(function() {
        if (!_isLoaded) {
          return true;
        }
      }, 1000);
    } else {
      return _isLoaded = true;
    }
  };

  dataAutoReload = {
    interval: null,
    init: function() {
      var intervalF, intervalSeconds;
      if (!app_config.autoReloadInterval) {
        return;
      }
      intervalSeconds = app_config.autoReloadInterval * 1000;
      if (dataAutoReload.interval) {
        clearInterval(dataAutoReload.interval);
      }
      intervalF = function() {
        return reloadSearchData();
      };
      return dataAutoReload.interval = setInterval(intervalF, intervalSeconds);
    }
  };

  confirmDialog = null;

  activeTimeEntryId = null;

  prevTimeEntry = null;

  initDeleteDialog = function() {
    var actions, close_button, dialog_message, dialog_title, no_button, titlebar, yes_button;
    confirmDialog = document.createElement("dialog");
    confirmDialog.className = "confirm-dialog";
    titlebar = document.createElement("div");
    titlebar.className = "dialog-titlebar";
    dialog_title = document.createElement("div");
    dialog_title.className = "dialog-title";
    dialog_title.id = "confirm_delete_title";
    dialog_title.setAttribute("role", "heading");
    dialog_title.setAttribute("aria-level", "2");
    close_button = document.createElement("button");
    close_button.className = "dialog-close";
    close_button.type = "button";
    close_button.setAttribute("aria-label", app_config.datepicker.closeText);
    close_button.textContent = "×";
    close_button.addEventListener("click", function() {
      return confirmDialog.close();
    });
    titlebar.append(dialog_title, close_button);
    dialog_message = document.createElement("div");
    dialog_message.className = "dialog-message";
    dialog_message.id = "confirm_delete_message";
    actions = document.createElement("div");
    actions.className = "dialog-actions";
    no_button = document.createElement("button");
    no_button.type = "button";
    no_button.textContent = translate("general_text_no");
    no_button.addEventListener("click", function() {
      return confirmDialog.close();
    });
    yes_button = document.createElement("button");
    yes_button.type = "button";
    yes_button.textContent = translate("general_text_yes");
    yes_button.addEventListener("click", function() {
      confirmDialog.close();
      return deleteTimeEntry(activeTimeEntryId);
    });
    actions.append(no_button, yes_button);
    confirmDialog.append(titlebar, dialog_message, actions);
    confirmDialog.setAttribute("aria-labelledby", dialog_title.id);
    confirmDialog.setAttribute("aria-describedby", dialog_message.id);
    return document.body.append(confirmDialog);
  };

  timeFormat = function(hours, minutes) {
    var r;
    r = [];
    if (hours) {
      r.push(hours, translate("field_hours").toLowerCase());
    }
    if (minutes) {
      r.push(minutes, translate("field_minutes").toLowerCase());
    }
    return r.join(" ");
  };

  confirmDelete = function() {
    var hours, message, minutes;
    hours = helper.$$("#hours").val();
    minutes = helper.$$("#minutes").val();
    message = timeFormat(hours, minutes) + "<br/><br/>" + helper.$$("#search").val();
    confirmDialog.querySelector(".dialog-title").textContent = translate("confirm_delete");
    confirmDialog.querySelector(".dialog-message").innerHTML = message;
    return confirmDialog.showModal();
  };

  updateTimeEntry = function() {
    var formData;
    timer.stop();
    formData = getFormData();
    formData.new = false;
    if (validate(formData)) {
      return sync(formData).done(function(response) {
        exitEditMode();
        return helper.$$(document).trigger("timeEntriesReload", "inplace");
      });
    }
  };

  createTimeEntry = function() {
    var formData;
    formData = getFormData();
    formData.new = true;
    if (formData.issue_id) {
      return redmine.getSpentTime(formData.project_id, formData.issue_id).done(function(response) {
        formData.activeTimeEntry = {
          issue: {
            spent_hours: response["total"]
          }
        };
        if (validate(formData)) {
          return sync(formData).done(function(response) {
            return helper.$$(document).trigger("timeEntriesReload", "inplace");
          });
        }
      });
    } else {
      // validateOther does not need spent time for projects
      if (validate(formData)) {
        return sync(formData).done(function(response) {
          return helper.$$(document).trigger("timeEntriesReload", "inplace");
        });
      }
    }
  };

  getDisplayFormData = function() {
    var r;
    // gets the form data in a format that can be easily reinserted
    r = timeEntryReceiveToSendFormat(formDataToAPIData(getFormData()));
    if (r.project) {
      r.project.name = helper.$$("#search").val();
    }
    return r;
  };

  displayFormDataToDom = function(formData) {
    return timeEntryToDom(formData);
  };

  startEditMode = function(timeEntryId) {
    var ref, ref1;
    if (!timeEntryId) {
      throw "missing timeEntryId";
    }
    $("#timeEntries .active").removeClass("active");
    $(`#timeEntries [data-entry-id=${timeEntryId}]`).addClass("active");
    $("#wrapper").addClass("editMode");
    if (activeTimeEntryId) {
      activeTimeEntryId = timeEntryId;
      timeEntryToDom(cache.timeEntries[timeEntryId]);
      updateActivities((ref = getSearchFormData()) != null ? ref.project_id : void 0);
      return;
    }
    prevTimeEntry = getDisplayFormData();
    activeTimeEntryId = timeEntryId;
    helper.$$(".delete, .cancel").show();
    helper.$$(".delete").on("click", confirmDelete);
    helper.$$("button.submit").addClass("update").html(translate("button_update")).off("click").on("click", updateTimeEntry);
    helper.$$("button.cancel").one("click", exitEditMode);
    $(document).on("keyup.time_logging_app", function(event) {
      if ("Escape" === event.key) {
        return exitEditMode();
      }
    });
    timeEntryToDom(cache.timeEntries[timeEntryId]);
    return updateActivities((ref1 = getSearchFormData()) != null ? ref1.project_id : void 0);
  };

  exitEditMode = function() {
    var searchFormData;
    activeTimeEntryId = false;
    $(document).off("keyup.time_logging_app");
    helper.$$(".delete,.cancel").off("click");
    helper.$$(".delete,.cancel").hide();
    helper.$$("button.submit").removeClass("update").html(translate("button_create")).off("click").click(createTimeEntry);
    displayFormDataToDom(prevTimeEntry);
    $("#timeEntries .active").removeClass("active");
    $("#wrapper").removeClass("editMode");
    helper.$$(".resetForm").show();
    searchFormData = getSearchFormData();
    updateActivities(searchFormData != null ? searchFormData.project_id : void 0);
    openInRedmineUpdateURL(searchFormData);
    return prevTimeEntry = false;
  };

  deleteTimeEntry = function(id) {
    return redmine.deleteTimeEntry(id).done(function() {
      exitEditMode();
      helper.$$(document).trigger("timeEntriesReload", "inplace");
      return resetForm();
    });
  };

  createTimeEntriesUrl = function(timeEntry) {
    var major, minor, ref, ref1, result;
    major = app_config.redmine.version_major;
    minor = app_config.redmine.version_minor;
    if (major > 3 || (major === 3 && minor >= 4)) {
      result = app_config.redmine.urls.projects_redmine + "/" + timeEntry.project.id + "/time_entries";
      if (((ref = timeEntry.issue) != null ? ref.id : void 0) != null) {
        return result + "?issue_id=~" + timeEntry.issue.id;
      } else {
        return result;
      }
    } else {
      if (((ref1 = timeEntry.issue) != null ? ref1.id : void 0) != null) {
        return app_config.redmine.urls.issues_redmine + "/" + timeEntry.issue.id + "/time_entries";
      } else {
        return app_config.redmine.urls.projects_redmine + "/" + timeEntry.project.id + "/time_entries";
      }
    }
  };

  timeEntryToTableRow = function(a, even) {
    var classes, estimated_hours, estimates, name, project, projectOrIssueUrl, ref, ref1, spent_hours, time;
    classes = [(even ? "even" : "odd")];
    if (a.issue) {
      name = helper.createIssueSearchDataEntry(cache.issues[a.issue.id], cache.projects);
      if (name) {
        name = name.value;
      }
      projectOrIssueUrl = app_config.redmine.urls.issues_redmine + "/" + a.issue.id;
    } else {
      // is project
      projectOrIssueUrl = app_config.redmine.urls.projects_redmine + "/" + a.project.id;
      project = cache.projects[a.project.id];
      if (project) {
        name = helper.createProjectSearchDataEntry(project);
        if (name) {
          name = name.value;
        }
      } else {
        console.warn(`project not available, id \"${a.project.id}\"`);
        classes.push("unavailable-project");
        name = translate("unavailable_project");
      }
    }
    time = helper.decimalHoursToColonFormat(a.hours);
    // get spent hours
    spent_hours = ((ref = a.issue) != null ? ref.spent_hours : void 0) || a.project.spent_hours;
    if (isNaN(spent_hours)) {
      spent_hours = 0;
    } else {
      // round value to nearest hour unless smaller than one hour
      spent_hours = spent_hours >= 1 ? Math.round(spent_hours) : helper.decimalHoursToColonFormat(spent_hours);
    }
    // get estimated hours
    estimated_hours = ((ref1 = a.issue) != null ? ref1.estimated_hours : void 0) || a.project.estimated_hours;
    if (isNaN(estimated_hours)) {
      estimated_hours = 0;
    } else {
      estimated_hours = estimated_hours >= 1 ? Math.round(estimated_hours) : helper.decimalHoursToColonFormat(estimated_hours);
    }
    estimates = spent_hours + (estimated_hours ? "/" + estimated_hours : "");
    if (estimated_hours) {
      if (spent_hours >= estimated_hours) {
        classes.push("overbooked");
      } else if (spent_hours / estimated_hours >= 0.8) {
        classes.push("almost-overbooked");
      }
    }
    // create html
    return cache.template.timeEntry({
      entry_id: a.id,
      time: time,
      estimates: estimates,
      name: name,
      comments: (a.comments ? helper.escapeHtml(a.comments) : ""),
      activity: cache.activities[a.activity.id].name,
      projectOrIssueUrl: projectOrIssueUrl,
      timeEntriesUrl: createTimeEntriesUrl(a),
      classes: classes.join(" ")
    });
  };

  insertTimeEntryRows = function(timeEntries) {
    var targetEle;
    targetEle = helper.$$("#timeEntries tbody");
    timeEntries.forEach(function(a, index) {
      var even, val;
      even = (index % 2) === 0;
      if (a.issue && !cache.issues[a.issue.id]) {
        // is a time entry of an issue that has not been loaded while getting issues (for example an old closed issue or a new issue).
        // we handle it by using the available time entry information
        cache.issues[a.issue.id] = a.issue;
        val = timeEntryToSearchDataEntry(a);
        cache.searchData.push(val);
      }
      return targetEle.append(timeEntryToTableRow(a, even));
    });
  };

  insertTimeEntryAsNew = function(timeEntryId) {
    if (!timeEntryId) {
      throw "missing timeEntryId";
    }
    return timeEntryToDom(cache.timeEntries[timeEntryId]);
  };

  displayTimeEntries = function(timeEntries, config) {
    var daySpentTime;
    helper.$$("#timeEntries tbody").children().remove();
    if (timeEntries.length) {
      // timeEntries in the format as retrieved from the backend interface
      daySpentTime = timeEntries.reduce(function(result, a) {
        return result + a.hours;
      }, 0);
      helper.$$(".daySpentTime").html(helper.decimalHoursToColonFormat(daySpentTime));
      insertTimeEntryRows(timeEntries);
      $(".timeEntry .edit").click(function() {
        var timeEntryId;
        timeEntryId = parseInt($(this).parents(".timeEntry:first").data("entry-id"));
        return startEditMode(timeEntryId);
      }).attr("title", translate("button_edit"));
      if (config && config.animation === "inplace") {
        // jquery highlight effect was not working
        helper.$$("#timeEntries").show();
      } else {
        helper.$$("#timeEntries").show()[0].animate([
          { opacity: 0, transform: "translateY(12px)" },
          { opacity: 1, transform: "translateY(0)" }
        ], {
          duration: 220,
          easing: "ease-out"
        });
      }
      return $(".timeEntry .insert").click(function() {
        var timeEntryId;
        timeEntryId = parseInt($(this).parents(".timeEntry:first").data("entry-id"));
        return insertTimeEntryAsNew(timeEntryId);
      }).attr("title", translate("button_duplicate"));
    } else {
      return helper.$$("#timeEntries").hide();
    }
  };

  cacheTimeEntries = function(apiTimeEntries) {
    apiTimeEntries.forEach(function(a) {
      return cache.timeEntries[a.id] = a;
    });
  };

  getTimeEntries = function(data, config, noEntriesFound) {
    if (cache.user_id === undefined) {
      throw "getTimeEntries - user_id is not set";
    }
    if (!config || !config.animation) {
      helper.$$("#timeEntries").hide();
      loading();
    }
    return redmine.getTimeEntries(data).done(function(response) {
      var timeEntries;
      timeEntries = response.time_entries;
      cacheTimeEntries(response.time_entries);
      return displayTimeEntries(response.time_entries, config);
    }).always(function(response) {
      helper.$$("#loading .icon").hide();
      if (response.time_entries && (response.time_entries.length === 0)) {
        if ((!noEntriesFound) || (!noEntriesFound())) {
          return helper.$$("#loading .text").html(translate("no_time_entries_loaded"));
        }
      } else {
        return loading(false);
      }
    });
  };

  timeEntryToSearchDataEntry = function(a) {
    if (a.issue) {
      a.issue = Object.assign(a.issue, cache.issues[a.issue.id]);
      a.issue.project = {
        id: a.project.id
      };
      return helper.createIssueSearchDataEntry(a.issue, cache.projects);
    } else {
      if (a.project) {
        return helper.createProjectSearchDataEntry(cache.projects[a.project.id]);
      }
    }
  };

  hasReceiveFormat = function(a) {
    return a && typeof a === "object" && a.hours && a.spent_on && (!a.activity || a.activity.id) && (!a.project || a.project.id) && (!a.issue || a.issue.id);
  };

  timeEntryReceiveToSendFormat = function(a) {
    var receiveFormat;
    if (debug && !hasReceiveFormat(a)) {
      console.warn("timeEntryReceiveToSendFormat - wrong type for argument", a);
    }
    // redmines post- and get-formats for time entries differ. see below for differing keys
    receiveFormat = {
      hours: a.hours,
      comments: a.comments,
      spent_on: a.spent_on
    };
    if (a.activity_id) {
      receiveFormat.activity = {
        id: a.activity_id
      };
    }
    if (a.issue_id) {
      receiveFormat.issue = {
        id: a.issue_id
      };
    }
    if (a.project_id) {
      receiveFormat.project = {
        id: a.project_id
      };
    }
    return receiveFormat;
  };

  timeEntryToDom = function(timeEntry) {
    var hours, minutes, ref, ref1, val;
    // insert time entry data into form fields.
    // in the format as received from the backend interface
    [hours, minutes] = helper.decimalHoursToHoursAndMinutes(timeEntry.hours);
    helper.$$("#hours").val((hours && (0 !== hours) ? hours : ""));
    helper.$$("#minutes").val((minutes && (0 !== minutes) ? minutes : ""));
    val = timeEntry.comments;
    helper.$$("#comments").val((val ? val : ""));
    val = timeEntry.activity && timeEntry.activity.id;
    helper.$$("#activity").val((val ? val : ""));
    val = timeEntryToSearchDataEntry(timeEntry);
    helper.$$("#search").val(val ? val.value : "");
    helper.$$("#search").blur();
    helper.$$("input[type=text],textarea,select").each(helper.removeErrorClass);
    return openInRedmineUpdateURL({
      issue_id: (ref = timeEntry.issue) != null ? ref.id : void 0,
      project_id: (ref1 = timeEntry.project) != null ? ref1.id : void 0
    });
  };

  extendBase = function() {
    var baseCreateTimeEntry;
    baseCreateTimeEntry = createTimeEntry;
    return createTimeEntry = function() {
      var r;
      r = baseCreateTimeEntry();
      if (r) {
        return r.done(function() {
          return helper.$$(document).trigger("timeEntriesReload", "inplace");
        });
      } else {
        return r;
      }
    };
  };

  dateIsWeekend = function(date) {
    return (date.getDay() === 6) || (date.getDay() === 0);
  };

  dateYmdEqual = function(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  };

  hideNextDateButton = function(selectedDate) {
    var a, button;
    a = selectedDate || helper.$$("#date").datepicker("getDate");
    button = helper.$$("button.next");
    if (dateYmdEqual(a, new Date())) {
      return button.hide();
    } else {
      return button.show();
    }
  };

  datepickerChangeDays = function(element, difference) {
    var nextDate, prevDate;
    prevDate = element.datepicker("getDate");
    nextDate = helper.copyDateObject(prevDate);
    nextDate.setDate(prevDate.getDate() + difference);
    if (nextDate !== prevDate) {
      element.datepicker("setDate", nextDate);
      return datepickerUpdate(function() {
        if (dateIsWeekend(nextDate)) {
          // no entries found
          return datepickerChangeDays(helper.$$("#date"), Math.min(difference, 1));
        }
      });
    }
  };

  incrementDate = function() {
    return datepickerChangeDays(helper.$$("#date"), 1);
  };

  decrementDate = function() {
    return datepickerChangeDays(helper.$$("#date"), -1);
  };

  onTimeEntriesReload = function(event, animation) {
    var config;
    config = animation ? {
      animation: animation
    } : void 0;
    return getTimeEntries({
      spent_on: helper.$$("#date").datepicker("getDate")
    }, config);
  };

  initialize_dom_cache = function() {};

  timer = {
    interval: null,
    startTime: null,
    getElapsedSeconds: function() {
      var endTime;
      endTime = Date.now();
      return (endTime - timer.startTime) / 1000;
    },
    getFormTime: function() {
      var hours, minutes;
      hours = helper.falseIfNaN(parseInt(helper.$$("#hours").val()));
      minutes = helper.falseIfNaN(parseInt(helper.$$("#minutes").val()));
      return helper.hoursAndMinutesToSeconds(hours, minutes);
    },
    setFormTime: function(seconds) {
      var hours, minutes;
      [hours, minutes] = helper.secondsToHoursAndMinutes(seconds);
      if (hours) {
        helper.$$("#hours").val(hours);
      }
      if (minutes) {
        return helper.$$("#minutes").val(minutes);
      }
    },
    start: function() {
      var intervalF;
      timer.startTime = Date.now();
      intervalF = function() {
        var hours, minutes, seconds;
        [hours, minutes, seconds] = helper.secondsToHoursAndMinutesAndSeconds(timer.getElapsedSeconds());
        return document.title = "⏱ " + hours + ":" + minutes + ":" + seconds;
      };
      timer.interval = setInterval(intervalF, 1000);
      timer.dom.startStopTimerButton.addClass("running");
      return intervalF();
    },
    stop: function() {
      if (timer.startTime === null) {
        return;
      }
      clearInterval(timer.interval);
      timer.setFormTime(timer.getFormTime() + timer.getElapsedSeconds());
      timer.startTime = null;
      timer.dom.startStopTimerButton.removeClass("running");
      return document.title = timer.originalTitle;
    },
    toggle: function() {
      if (timer.startTime === null) {
        return timer.start();
      } else {
        return timer.stop();
      }
    },
    init: function() {
      var button;
      button = $("button.start-stop-timer");
      timer.originalTitle = document.title;
      timer.dom = {
        startStopTimerButton: button
      };
      return button.click(function() {
        return timer.toggle();
      });
    }
  };

  initialize = function() {
    var datepicker_date, lang, selectEle, time_entry_template, token, user;
    helper.mobileHideAddressBar();
    loading();
    dom.openInRedmineButton = $("button.open-in-redmine");
    // activities
    selectEle = helper.$$("#activity");
    cache.activities = {};
    redmineData.activities.forEach(function(a) {
      selectEle.append($("<option>").attr("value", a.id).html(a.name));
      return cache.activities[a.id] = a;
    });
    updateActivities(-1);
    // current user
    user = redmineData.user;
    cache.user_id = user.id;
    lang = user.language;
    cache.user_language = lang;
    // csrf token. important, otherwise "internal server error"s occur
    token = redmineData.csrf_token;
    $.ajaxPrefilter(function(options, origOptions, request) {
      if (options.type.match(/(post)|(put)|(delete)/i)) {
        return request.setRequestHeader("X-CSRF-Token", token);
      }
    });
    // datepicker
    helper.$$("#date").datepicker(app_config.datepicker);
    if (redmineData.spent_on) {
      datepicker_date = new Date(redmineData.spent_on);
      helper.$$("#date").datepicker("option", "minDate", "-180d");
    } else {
      datepicker_date = "+0";
    }
    helper.$$("#date").datepicker("setDate", datepicker_date);
    // buttons and fields
    $("button.overview").click(function() {
      return window.open($(this).data("href"), "_newtab");
    });
    dom.openInRedmineButton.hide().click(function() {
      var url;
      url = $(this).data("href");
      if (url) {
        return window.open(url, "_blank");
      }
    });
    timer.init();
    $("#hours,#minutes").keydown(helper.onKeypressRejectNaN);
    $(".submit").click(function() {
      return createTimeEntry();
    });
    $(".resetForm").click(resetFormButton);
    openInRedmineUpdateURL();
    // search-field
    return getIssuesProjectsAndSearchData(app_config.issueStatus).done(function() {
      helper.$$("h2:first").show();
      helper.$$("#form").show();
      loading(false);
      dataAutoReload.init();
      helper.$$("#search").val("");
      // editing
      time_entry_template = $("#timeEntryTemplate").text();
      cache.template.timeEntry = function(data) {
        return time_entry_template.replace(/\{\{(.+?)\}\}/g, function(match, key) {
          return data[key] == null ? "" : data[key];
        });
      };
      extendBase();
      initDeleteDialog();
      onTimeEntriesReload();
      helper.$$(document).on("timeEntriesReload", onTimeEntriesReload);
      helper.$$("#date").datepicker("option", "onSelect", function() {
        return datepickerUpdate();
      });
      $(".dateControls .prev").click(decrementDate);
      $(".dateControls .next").click(incrementDate);
      hideNextDateButton();
      window.dispatchEvent(new CustomEvent("timeEntryEditing"));
      return $("#wrapper").show();
    });
  };

  setDate = function(date) {
    helper.$$("#date").datepicker("setDate", date);
    return datepickerUpdate();
  };

  datepickerUpdate = (function() {
    var request;
    request = void 0;
    return function(noEntriesFound) {
      var date;
      if (request && (request.state() === "pending")) {
        request.abort();
        request = false;
      }
      date = helper.$$("#date").datepicker("getDate");
      hideNextDateButton(date);
      return request = getTimeEntries({
        spent_on: date
      }, false, noEntriesFound);
    };
  })();

  return {
    config: app_config,
    initialize: initialize
  };

})();
