# frozen_string_literal: true

module Scheduled
  class DatabaseVacuumJob < BaseJob
    def perform
      ActiveRecord::Base.connection.execute("VACUUM")
    end
  end
end
