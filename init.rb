require "redmine"

Redmine::Plugin.register :redmine_time_logging_app do
  name "redmine time logging app"
  author "intera gmbh"
  author_url "https://github.com/intera"
  description "adds a new menu entry to log and edit spent time in one place"
  version "1.0.0"
  menu(
       :top_menu, :time_logging_app, {:controller => :time_logging_app, :action => :time_entry}, :caption => :menu_entry_title,
       :html => {:target => "_blank"},
       :if => Proc.new {
         # require relevant permissions to show the menu entry
         User.current.allowed_to?(:log_time, nil, :global => true) ||
         User.current.allowed_to?(:edit_own_time_entries, nil, :global => true) ||
         User.current.admin?
       })
end
