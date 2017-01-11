# time logging app
this redmine plugin adds a new menu entry and separate section to log and edit ones own spent time in one place, in a quick way.

# features
* a mobile-app like interface
* powerful autocomplete that searches projects, issues and versions that accepts word fragments in any order
* lists spent time entries per day and allows to switch fast between days
* automatically skips weekends if there is no time entry
* time entry creation/edit/copy/delete
* existing time entries can be used as a template
* link to an overview page that lists the total hours per day
* shows individual and general total spent time for issues and projects
* a click on the logged hours or activity opens the redmine time entry view for the issue or project
* open issue/project button
* translatable

# browser support
at the moment the plugin probably does not work with internet explorer.

# installation
## download
dowload a [release](https://github.com/Intera/redmine_time_logging_app/releases) or a [zip file](https://github.com/Intera/redmine_time_logging_app/archive/master.zip) via github and unpack the archive.
alternatively, you can clone the source code repository with "git clone https://github.com/Intera/redmine_time_logging_app.git".

## setup
make sure that "enable rest web service" is activated in redmine under "Administration" -> "Settings" -> "Authentication".
move the "redmine_time_logging_app" directory from the download to your redmine instance directory to "plugins/", so that it lies at "plugins/redmine_time_logging_app".
on the command-line, change into the redmine instance directory and execute "bundle install".
if that ran successful and the file system permissions are right, the plugin should now be installed. go into redmine under "Administration" -> "Plugins" to check that it is listed, and eventually use the configure link there to adjust settings of the plugin.

# usage
after successful installation, if the current redmine user has the redmine permissions to log time and to edit own time entries, a menu entry "Time Logging" or similar in the topmost navigation bar in redmine should be visible.
clicking on the menu entry should open a new browser tab where the time entry editor app appears.

if you have made time entries today, a list of your spent time entries for today is displayed.
you can use the left/right arrow buttons at the top left, or the date field and date picker, to switch between days.

to create a new spent time entry, use the search field to search and select the desired issue or project, fill in at least a time and activity and click "create". redmine will ask you once every time your browser has restarted to enter your redmine username and password to ensure that you have permission to create or edit time entries.
comments can be at most 255 characters long.

to edit a time entry, click on the pencil button in the list of time entries. you can change the date freely. when you click on "update" the changes will be saved.

# configuration
there is a configuration file at vendor/app/js/config.coffee.
it contains configuration for the datepicker and the rest of the application.
following are only a few of the available options. most options are only relevant for developers.

## app cofiguration
|issueClosedPastDays|7|include closed issues as long as they are not older than the given number of days|
|issueStatus|undefined|only include issues with the specified status. possible values are "open", "closed", "*" or the id of any redmine status|
|autocompleteMinLength|3|the minimum number of characters until the search field looks for suggestions|
|baseURL|getBaseURL|a function that returns the path to the redmine root relative to the webserver root. "/" by default|

## datepicker configuration
|maxDate|+0||
|minDate|-6m|the earliest selectable date|
|dateFormat|"D d.m.y"||
|firstDay|1||

at the moment, changing the configuration requires recompilation of the javascript application, see below.

# developer information
## development dependencies
* nodejs

## setup
* change directory to vendor/app
* execute "npm install" on the command-line to install all the development dependencies

## interesting files
* app/controllers/time_logging_app_controller.rb is the backend interface
* the javascript application is under vendor/app and written in coffeescript
* files under assets/ are automatically created/updated by the build tool in vendor/app
* config/locales/* and vendor/app/js/utility.coffee contain the translations

## how to add a new translation language
* copy one of the files in config/locales to a new one named with the appropriate language code.
* in vendor/app/js/utility.coffee, copy one of the "translations["en"] ..." and use the new language code instead of "en".
* the datepicker month and day names can be overridden in vendor/app/config.coffee but it is currently not implemented to set it for multiple languages
* recompile the javascript application, see below for how to do this

## how to recompile the javascript application
* in directory vendor/app
* execute the nodejs script "./exe/compile". if this does not work, try "node exe/compile"
* changes will only be visible after a redmine restart, because redmine copies plugin assets only when it starts

## other
it is possible to replace the jquery-ui theme.

## possible enhancements
* make the date format easier to configure
* make it easy to configure multi language datepicker configurations
* internet explorer support
