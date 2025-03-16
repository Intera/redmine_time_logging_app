get "time_logging_app", to: "time_logging_app#index"
get "time_logging_app/show", to: "time_logging_app#show"
get "time_logging_app/edit", to: "time_logging_app#edit"
match "time_logging_app/time_entries", to: "time_logging_app#time_entries", via: [:get, :post, :put, :delete]

get "time_logging_app/projects_and_issues", to: "time_logging_app#projects_and_issues"
get "time_logging_app/recent", to: "time_logging_app#recent"
get "time_logging_app/spent_time", to: "time_logging_app#spent_time"
get "time_logging_app/overview", to: "time_logging_app#overview"
