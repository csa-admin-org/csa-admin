# frozen_string_literal: true

module Demo
  class ResetJob < ActiveJob::Base
    queue_as :low

    def perform
      Tenant.demo_tenants.each do |tenant|
        Tenant.switch(tenant) do
          Demo::Seeder.new.seed!
        end
      end
    end
  end
end
