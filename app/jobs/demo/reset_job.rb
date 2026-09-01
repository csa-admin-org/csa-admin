# frozen_string_literal: true

module Demo
  class ResetJob < ActiveJob::Base
    queue_as :low

    def perform
      Tenant.switch_each(Tenant.demo_tenants) do
        Demo::Seeder.new.seed!
      end
    end
  end
end
