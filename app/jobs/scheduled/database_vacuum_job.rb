# frozen_string_literal: true

module Scheduled
  class DatabaseVacuumJob < BaseJob
    limits_concurrency key: ->(*) { "database-vacuum" }

    def perform
      ActiveRecord::Base.connection.execute("VACUUM")
    end
  end
end
