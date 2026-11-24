// Time Logging App - JavaScript source converted from CoffeeScript 2.7.0 output.
const timeLoggingAppHelper = (function() {
  var $$, autocompleteMatchFunc, config, copyDateObject, createIssueSearchDataEntry, createProjectSearchDataEntry, createProjectsIssuesAndSearchData, decimalHoursToColonFormat, decimalHoursToHoursAndMinutes, defaultDialogConfig, delim, displayDialog, entityMap, escapeHtml, falseIfNaN, getBrowserLanguage, hoursAndMinutesToSeconds, issueIdToUrl, mobileHideAddressBar, onKeypressRejectNaN, padZeros, projectNameToId, removeErrorClass, roundFloat, secondsToHoursAndMinutes, secondsToHoursAndMinutesAndSeconds, selectAll, setCursorPosition, setSelectionRange, stringContains, stringContainsEvery, timeLimitedFunc, wrapDeferred;

  config = timeLoggingAppConfig;

  $$ = (function() {
    var cache;
    // like $, but caches results. for elements that dont change after page load
    cache = {};
    return function(s) {
      var e;
      if (cache.hasOwnProperty(s)) {
        return $(cache[s]);
      } else {
        e = jQuery(s);
        if (e.length > 0) {
          cache[s] = e;
        }
        return e;
      }
    };
  })();

  timeLimitedFunc = function(func, wait) {
    var next, prev;
    // only actually call the wrapped function when at least "wait" seconds have passed since the last actual call.
    prev = 0;
    next = void 0;
    return function() {
      next = +new Date();
      if ((next - prev) > wait) {
        prev = next;
        return func.apply(this, arguments);
      }
    };
  };

  getBrowserLanguage = function() {
    var lang;
    if (navigator && navigator.userAgent && (lang = navigator.userAgent.match(/android.*\W(\w\w)-(\w\w)\W/i))) {
      // WebView on Android would always return "en" in navigator.*language, parse userAgent instead
      lang = lang[1];
    }
    if (!lang && navigator) {
      if (navigator.language) {
        lang = navigator.language;
      } else if (navigator.browserLanguage) {
        lang = navigator.browserLanguage;
      } else if (navigator.systemLanguage) {
        lang = navigator.systemLanguage;
      } else {
        if (navigator.userLanguage) {
          lang = navigator.userLanguage;
        }
      }
    }
    return lang.substr(0, 2);
  };

  stringContains = function(a, b) {
    return a.indexOf(b) >= 0;
  };

  stringContainsEvery = function(a, values) {
    return values.every(function(b) {
      return stringContains(a, b);
    });
  };

  autocompleteMatchFunc = function(searchstring) {
    var firstIsWhitespace, lastIsWhitespace, matchCount, patterns;
    // searches for words, ignoring special chars, in any order, case insensitive, keeping one leading and one trailing whitespace.
    // also searchs for the case insensitive search string as typed.
    matchCount = 0;
    patterns = searchstring.split(" ");
    lastIsWhitespace = "" === patterns[patterns.length - 1];
    firstIsWhitespace = "" === patterns[0];
    patterns = patterns.filter(function(e) {
      return e !== "";
    });
    patterns = patterns.map(function(a) {
      return a.toLowerCase();
    });
    // keep a leading and trailing whitespace because if a user enters it they might want to search with it
    if (lastIsWhitespace) {
      patterns[patterns.length - 1] += " ";
    }
    if (firstIsWhitespace) {
      patterns[0] = " " + patterns[0];
    }
    return function(item, index) {
      var value;
      if (matchCount >= config.autocompleteLimit) {
        return false;
      } else {
        value = item.value.toLowerCase();
        if (stringContainsEvery(value, patterns) || stringContains(value, searchstring)) {
          matchCount += 1;
          return true;
        } else {
          return false;
        }
      }
    };
  };

  selectAll = function() {
    return this.select();
  };

  wrapDeferred = function(func) {
    return function(arg) {
      func(arg);
      return arg;
    };
  };

  projectNameToId = function(projects, name) {
    var i, keys;
    keys = Object.keys(projects);
    i = 0;
    while (i < keys.length) {
      if (projects[keys[i]].name === name) {
        return keys[i];
      }
      i += 1;
    }
    return false;
  };

  createProjectsIssuesAndSearchData = function(projects, issues) {
    var searchData;
    // convert redmine result arrays. {"projects": [project-data, ...]} -> {project-id: project-data, ...}
    // and fill searchData array.
    searchData = [];
    projects = projects.reduce(function(prev, a) {
      if (!redmineData.only_issues) {
        // insert projects into searchData
        searchData.push(createProjectSearchDataEntry(a));
      }
      // insert into projects object
      prev[a.id] = a;
      return prev;
    }, {});
    issues = issues.reduce(function(prev, a) {
      // insert into searchData
      searchData.push(createIssueSearchDataEntry(a, projects));
      prev[a.id] = a;
      return prev;
    }, {});
    return [projects, issues, searchData];
  };

  delim = config.issueNameDelimiter;

  createProjectSearchDataEntry = function(project) {
    var label;
    if (project.parent) {
      label = `${project.parent.name}${delim}${project.name}`;
    } else if (project.parent_name) {
      label = `${project.parent_name}${delim}${project.name}`;
    } else {
      label = project.name;
    }
    return {
      label: label,
      value: label
    };
  };

  createIssueSearchDataEntry = function(issue, projects) {
    var issueString, label, project;
    project = projects[issue.project.id];
    issueString = `#${issue.id} ${issue.subject}`;
    if (issue.version) {
      issueString = `${issue.version}${delim}${issueString}`;
    }
    if (project) {
      if (project.parent_name) {
        label = `${project.parent_name}${delim}${project.name}${delim}${issueString}`;
      } else {
        label = `${project.name}${delim}${issueString}`;
      }
    } else {
      label = issueString;
    }
    return {
      label: label,
      value: label,
      is_closed: issue.is_closed
    };
  };

  setSelectionRange = function(element, selectionStart, selectionEnd) {
    var range;
    if (element.setSelectionRange) {
      element.focus();
      return element.setSelectionRange(selectionStart, selectionEnd);
    } else if (element.createTextRange) {
      range = element.createTextRange();
      range.collapse(true);
      range.moveEnd("character", selectionEnd);
      range.moveStart("character", selectionStart);
      return range.select();
    }
  };

  setCursorPosition = function(element, pos) {
    return setSelectionRange(element, pos, pos);
  };

  padZeros = function(number, totalLength) {
    var missingZeros, numberString;
    numberString = "" + number;
    missingZeros = numberString.length % totalLength;
    while (missingZeros--) {
      numberString = "0" + numberString;
    }
    return numberString;
  };

  falseIfNaN = function(a) {
    if (isNaN(a)) {
      return false;
    } else {
      return a;
    }
  };

  onKeypressRejectNaN = function(event) {
    var charCode;
    // NaN is a number - this is why we don't use "isNumber"
    charCode = (event.which ? event.which : event.keyCode);
    // -> is numeric?
    // standard number keyrange || numpad number keyrange || tab || backspace || delete || lr arrows
    return ((charCode > 47) && (charCode < 58)) || ((charCode > 95) && (charCode < 106)) || (charCode === 9) || (charCode === 8) || (charCode === 46) || (charCode === 37) || (charCode === 39);
  };

  decimalHoursToHoursAndMinutes = function(a) {
    var hours, minutes;
    hours = Math.floor(a);
    minutes = Math.round(a * 60 % 60);
    if (60 === minutes) {
      return [hours + 1, 0];
    } else {
      return [hours, minutes];
    }
  };

  decimalHoursToColonFormat = function(a) {
    var hours, minutes, res;
    [hours, minutes] = decimalHoursToHoursAndMinutes(a);
    res = "";
    if (hours) {
      res += hours;
    }
    if (minutes) {
      res += ":" + padZeros(minutes, 2);
    }
    return res;
  };

  mobileHideAddressBar = function() {
    var hideAddressBar;
    hideAddressBar = function() {
      if (!window.location.hash) {
        if (document.height <= window.outerHeight + 10) {
          document.body.style.height = (window.outerHeight + 50) + "px";
          return setTimeout((function() {
            return window.scrollTo(0, 1);
          }), 50);
        } else {
          return setTimeout((function() {
            return window.scrollTo(0, 1);
          }), 0);
        }
      }
    };
    window.addEventListener("load", hideAddressBar);
    return window.addEventListener("orientationchange", hideAddressBar);
  };

  issueIdToUrl = function(id) {
    return config.redmine.urls.issues_redmine + "/" + id;
  };

  removeErrorClass = function() {
    return $(this).removeClass(config.errorClass);
  };

  copyDateObject = function(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate(), date.getHours(), date.getMinutes());
  };

  defaultDialogConfig = {
    buttons: {
      "schließen": function() {
        return $(this).dialog("close");
      }
    },
    resizable: false,
    closeOnEscape: true,
    show: "fade",
    autoOpen: false
  };

  displayDialog = void 0;

  $(function() {
    var dialog;
    dialog = $("<div>").dialog(defaultDialogConfig);
    return displayDialog = function(message, title) {
      if (typeof message === "string") {
        dialog.html(message);
      } else {
        dialog.html("");
        dialog.append(message);
      }
      return dialog.dialog("option", "title", title).dialog("open");
    };
  });

  entityMap = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;",
    "/": "&#x2F;"
  };

  escapeHtml = function(string) {
    return String(string).replace(/[&<>"'\/]/g, function(s) {
      return entityMap[s];
    });
  };

  roundFloat = function(a) {
    return parseFloat(a.toPrecision(2));
  };

  secondsToHoursAndMinutes = function(seconds) {
    var hours, minutes;
    hours = Math.floor(seconds / 3600);
    minutes = Math.floor(seconds % 3600 / 60);
    return [hours, minutes];
  };

  secondsToHoursAndMinutesAndSeconds = function(seconds) {
    var hours, minutes;
    hours = Math.floor(seconds / 3600);
    minutes = Math.floor(seconds % 3600 / 60);
    seconds = Math.floor(seconds % 3600 % 60);
    return [hours, minutes, seconds];
  };

  hoursAndMinutesToSeconds = function(hours, minutes) {
    return (hours || 0) * 3600 + (minutes || 0) * 60;
  };

  return {
    $$: $$,
    autocompleteMatchFunc: autocompleteMatchFunc,
    copyDateObject: copyDateObject,
    createProjectsIssuesAndSearchData: createProjectsIssuesAndSearchData,
    createIssueSearchDataEntry: createIssueSearchDataEntry,
    createProjectSearchDataEntry: createProjectSearchDataEntry,
    decimalHoursToHoursAndMinutes: decimalHoursToHoursAndMinutes,
    decimalHoursToColonFormat: decimalHoursToColonFormat,
    defaultDialogConfig: defaultDialogConfig,
    escapeHtml: escapeHtml,
    falseIfNaN: falseIfNaN,
    issueIdToUrl: issueIdToUrl,
    onKeypressRejectNaN: onKeypressRejectNaN,
    projectNameToId: projectNameToId,
    removeErrorClass: removeErrorClass,
    selectAll: selectAll,
    padZeros: padZeros,
    roundFloat: roundFloat,
    stringContains: stringContains,
    wrapDeferred: wrapDeferred,
    mobileHideAddressBar: mobileHideAddressBar,
    setSelectionRange: setSelectionRange,
    setCursorPosition: setCursorPosition,
    timeLimitedFunc: timeLimitedFunc,
    hoursAndMinutesToSeconds: hoursAndMinutesToSeconds,
    secondsToHoursAndMinutes: secondsToHoursAndMinutes,
    secondsToHoursAndMinutesAndSeconds: secondsToHoursAndMinutesAndSeconds
  };

})();
