doctype 5
html ->
  head ->
    link type: "text/css", href: "/plugin_assets/time_logging_app/stylesheets/app/main.css", rel: "Stylesheet"
    title "Time Logging"
    meta 'http-equiv': "content-type", content: "text/html;charset=UTF-8"
    meta name: "csrf-token"
    meta name: "apple-mobile-web-app-capable", content: "yes"
    meta name: "viewport", content: "width=device-width,initial-scale=1.0"
  # body background-color is set here to have it early on load
  body style: "background-color: #999", ->
    div "#wrapper", style: "display:none", ->
      div ".entry", ->
        h2 style: "display:none"
        div "#form", ->
          div ".topControls", ->
            button ".duplicate", ""
            button ".delete", ""
          div ".hbox", ->
            input "#date", type: "text", tabindex: "1"
            div ".dateControls", ->
              button ".prev", ""
              button ".next", ""
            a ".open-in-redmine", target: "_blank"
            button ".reload-search-data", ""
            button ".emptyForm", ""
            a ".overview", target: "_blank", href: "time_logging_app/overview"
          textarea "#search", tabindex: "2", title: "Suche...", accesskey: "f"
          div ".hbox", ->
            div "#time", ->
              input "#hours", type: "text", tabindex: "3"
              input "#minutes", type: "text", tabindex: "4"
            select "#activity", title: "Aktivität wählen...", tabindex: "5"
          textarea "#comments", maxlength: "255", title: "Kommentar (optional)", tabindex: "6"
          div ".hbox", ->
            button ".cancel", ""
            button ".submit", accesskey: "s", tabindex: "7"
      div "#loading", ->
        span ".text", ""
        div ".icon", ""
      table "#timeEntries.list", ->
        thead ->
          tr ->
            th ".project-task-header", "Projekt\\Aufgabe"
            th ".hours-header", "Stunden"
            th ".activity-header", "Aktivität"
            th ".daySpentTime", title: "test"
        tbody()
        tfoot ->
          tr ->
            td ".hoursTotal", colspan: "4"
    script "#timeEntryTemplate", type: "text/html", "<tr class=\"timeEntry {{classes}}\" data-entry-id=\"{{entry_id}}\">
        <td><a target=\"_blank\" href=\"{{projectOrIssueUrl}}\">{{name}}</a><div class=\"comments\">{{comments}}</div></td><td><a target=\"_blank\" class=\"time\" href=\"{{timeEntriesUrl}}\">{{time}}</a></td><td><a target=\"_blank\" class=\"activity\" href=\"{{timeEntriesUrl}}\">{{activity}}</a></td><td><button class\"load\"></button><button class=\"edit\"></button></td></tr>"
    script type: "text/javascript", src: "main.js"
