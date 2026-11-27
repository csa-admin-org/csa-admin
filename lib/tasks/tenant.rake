# frozen_string_literal: true

namespace :tenant do
  desc "Remove a tenant in two phases (TENANT=x, dry-run unless CONFIRM=x)"
  task remove: :environment do
    Tenant::Remover.new(ENV["TENANT"], confirm: ENV["CONFIRM"]).run
  end
end
