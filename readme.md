# redmine time logging app
this redmine plugin adds a new menu entry and separate section to log and edit ones own spent time in one place, in a quick way.

![screenshot-1](other/screenshots/1484135564.png?raw=true)

# features
* a mobile-app like interface
* powerful autocomplete that searches projects, issues and versions that accepts word fragments in any order
* lists spent time entries per day and allows to switch fast between days
* automatically skips weekends if there is no time entry
* time entry creation/edit/copy/delete
* shows individual and general total spent time for issues and projects
* open issue/project button
* a click into an empty search field suggests issues recently changed by the user
* a click on the logged hours or activity opens the redmine time entry view for the issue or project
* link to an overview page that lists the total hours per day
* easily translatable. currently included languages are: de, en, ja
* tested with redmine 4 and 3

# browser support
the plugin does not work with internet explorer.

# installation
## download
dowload a [release](https://github.com/Intera/redmine_time_logging_app/releases) or a [zip file](https://github.com/Intera/redmine_time_logging_app/archive/master.zip) via github and unpack the archive.
alternatively, you can clone the source code repository with "git clone https://github.com/Intera/redmine_time_logging_app.git".

## setup
* move the "redmine_time_logging_app" directory from the download to your redmine instance directory to "plugins/", so that it lies at "plugins/redmine_time_logging_app"
* if the file system permissions are right, the plugin should now be installed
* restart redmine
* go into redmine under "Administration" -> "Plugins" to check that it is listed

# usage
after successful installation, if the current redmine user has the redmine permissions to log time and to edit own time entries, a menu entry "Time Logging" or similar in the topmost navigation bar in redmine should be visible.
clicking on the menu entry should open a new browser tab where the time entry editor app appears.

if you have made time entries today, a list of your spent time entries for today is displayed.
you can use the left/right arrow buttons at the top left, or the date field and date picker, to change between days.

to create a new spent time entry, use the search field to search and select the desired issue or project, fill in at least a time and activity and click "create".

to edit a time entry, click on the pencil button in the list of time entries. you can change the date freely. when you click on "update" the changes will be saved.

![screenshot-2](other/screenshots/arrows.png?raw=true)
![screenshot-3](other/screenshots/1484135578.png?raw=true)

# configuration
see "Administration" -> "Plugins" -> "redmine time logging app" -> "Configure".

|optionName|default|description|
----|----|----
|date format|"D d.m.y"|jQuery datepicker [format](https://api.jqueryui.com/datepicker/#utility-formatDate)|
|earliest selectable date|-6m|[format](https://api.jqueryui.com/datepicker/#option-minDate)|
|latest selectable date|+0|[format](https://api.jqueryui.com/datepicker/#option-minDate)|
|first day of week|1|0-6, sunday to monday|
|load closed issues of the past n days|7|include closed issues as long as they are not older than the given number of days|
|warn when exceeding estimated time|off|show a warning when trying to log time that would exceed the estimated time of the issue|
|Disallow logging time on projects|off|redmine allows spent time on issues and projects, this setting requires time entries to be for specific issues|

# developer information
## development dependencies
* nodejs

## how to add a new translation language
* copy one of the files in "config/locales/" to a new one named with the appropriate language code
* edit the file and replace the existing translations with your translations

the plugin tries to use the language that the user has configured in redmine under "my account" and falls back to english
## setup
* change directory to vendor/app
* execute "npm install" on the command-line to install the required nodejs modules at once (coffeescript, browserify, coffeeify and fs-extra)

## interesting files
* "app/controllers/time_logging_app_controller.rb" is the backend interface
* the javascript code is under "vendor/app/sources/js" and written as coffeescript
* files under "assets/" are automatically created/updated by the build tool in "vendor/app"
* "config/locales/*" are the translations
* "vendor/app/js/config.coffee" is an internal configuration file and contains some additional internal settings

## how to recompile the javascript application
* in directory "vendor/app"
* execute "./exe/compile". should that not work then try "node exe/compile"
* changes will only become active after a redmine restart, because redmine installs new plugin assets only when it starts

## other
it is possible to replace the jquery-ui theme.

## possible enhancements
* better language detection (en-gb for example seems to be incorrectly detected)
* loading indicator
* remove the focus style on buttons on touch devices (trying to fix it by overwriting .ui-state-focus css did not succeed)
