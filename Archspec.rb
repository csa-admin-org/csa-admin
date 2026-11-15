# frozen_string_literal: true

# Formatting helpers are included from Liquid drops, PDF, and CSV.
# Not a license to add app/services.
architecture :vanilla_rails, share_helpers: true
preset :ruby_conventions

# The Query API lives in app/models/query. This is the query-object directory.
component(:queries, in: "app/queries/**/*.rb")
  .must_be_empty(because: "behavior belongs on models, not query objects")
