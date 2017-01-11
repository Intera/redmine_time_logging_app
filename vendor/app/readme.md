# compilation
css and javascript files are compiled into the redmine plugin assets directory.
to recompile the files execute ''node exe/compile''.

# html
the html files are in "plugins/redmine_intera/app/views/time_logging_app".
not "html/index.coffee", this could theoretically be used if the html rendering is not integrated into redmine.

# jquery ui themes
downloaded jquery themes require replacement of the image paths in the css. (replace "url(image/" with "url(img/").
additionally, the directory structure has to be broken up, and images need to be put into the main "img/", css into the main "css/" and js into the main "js/" directories (under vendor/app/).
this simplifies the compile configuration considerably

# javascript file structure
* js/*.coffee are the modules of the application.
* js/lib/* are externally maintained modules.

the main entry point is "js/main.coffee".
all application modules/parts are consistently available in window.app.{module-name}

## about module names and where they occur
* module-name := string
* file-name := module-name ".coffee"
* module-variable := window.app.module-name

## short descriptions of the modules
js/
  |name|description|
  ----|----
  |config|configuration: look here first if you want to change something|
  |app|base application: time entry creation and display|
  |main|main entry point, loads all other modules via asynchronuous script loading|
  |timeEntryEditing|the edit mode for time-entries, technically optional|
  |redmine|a javascript redmine api|
  |utility|
