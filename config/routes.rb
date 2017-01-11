get 'time_logging_app', to: 'time_logging_app#time_entry'
match 'time_logging_app/:action', controller: 'time_logging_app', via: [:get, :post]
