# setup
npm install

# compilation
css and javascript files are compiled into the redmine plugin assets directory.
to recompile the files execute ''node exe/compile''.

# html
the html files are in "#{plugin_root}/app/views/time_logging_app".

# jquery ui themes
downloaded jquery themes require replacement of the image paths in the css. (replace "url(image/" with "url(img/").
additionally, the directory structure has to be broken up and images need to be put into the main "img/", css into the main "css/" and js into the main "js/" directories (under vendor/app/).
this simplifies the compile configuration

# javascript file structure
* uses browserify node modules
* js/*.coffee are the modules of the application.
* js/lib/* are externally maintained javascript files.

the main entry point is "js/main.coffee".
