require "redmine"

Redmine::Plugin.register :redmine_time_logging_app do
  name "Redmine Time Logging App"
  author "Intera GmbH"
  author_url "https://github.com/intera"
  description "Adds a new menu entry to log and edit spent time in one place"
  version "1.3"
  menu(
    :top_menu, :time_logging_app, {:controller => :time_logging_app, :action => :index}, :caption => :menu_entry_title,
    :html => {:target => "_blank"},
    :if => Proc.new {
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
             "only_issues" => "0",
             "overbooking_warning" => "0",
             "issues_closed_past_days" => 14
           }
end
