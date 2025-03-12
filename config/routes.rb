get "time_logging_app", to: "time_logging_app#index"
get "time_logging_app/show", to: "time_logging_app#show"
get "time_logging_app/edit", to: "time_logging_app#edit"
match "time_logging_app/time_entries", to: "time_logging_app#time_entries", via: [:post, :put, :delete]
