require "redmine"

Redmine::Plugin.register :redmine_time_logging_app do
  name "redmine time logging app"
  author "intera gmbh"
  author_url "https://github.com/intera"
  description "adds a new menu entry to log and edit spent time in one place"
  version "1.0.1"
  menu(
    :top_menu, :time_logging_app, {:controller => :time_logging_app, :action => :time_entry}, :caption => :menu_entry_title,
    :html => {:target => "_blank"},
    :if => Proc.new {
      # require relevant permissions for showing the menu entry
      User.current.allowed_to?(:log_time, nil, :global => true) ||
        User.current.allowed_to?(:edit_own_time_entries, nil, :global => true) ||
        User.current.admin?
    })
  settings :partial => "settings/redmine_time_logging_app_settings",
           :default => {
             "datepicker_max_date" => "+0",
             "datepicker_min_date" => "-6m",
             "datepicker_first_day" => 1,
             "datepicker_date_format" => "D y-m-d",
             "issues_closed_past_days" => 7
           }
end
