# frozen_string_literal: true

module Query
  class Walk
    def self.slugs(token:, tenants: nil)
      wanted = Array(tenants).flat_map { |value|
        value.to_s.split(",")
      }.map(&:strip).compact_blank
      allowed = Tenant.all.select { |slug| token.allows?(slug) }
      wanted.empty? ? allowed : allowed.intersection(wanted)
    end

    def self.each(token:, tenants: nil)
      Tenant.switch_each(slugs(token: token, tenants: tenants)) do
        next if Tenant.demo? || Tenant.custom?

        with_readonly { yield Tenant.current }
      end
    end

    def self.with_readonly
      connection = ActiveRecord::Base.lease_connection
      connection.execute("PRAGMA query_only = ON")
      ActiveRecord::Base.while_preventing_writes { yield }
    ensure
      connection&.execute("PRAGMA query_only = OFF")
    end
  end
end
