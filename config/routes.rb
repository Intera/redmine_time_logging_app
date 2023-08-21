get "time_logging_app", :to => "time_logging_app#index"
get "time_logging_app/:action", :controller => "time_logging_app"
match "time_logging_app/time_entries", :to => "time_logging_app#time_entries", :via => [:post, :put, :delete]
