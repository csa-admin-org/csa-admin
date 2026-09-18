# frozen_string_literal: true

module Query
  class BankConnectionsIndex
    ALLOWED = %w[provider name active state health_status].freeze
    FILTERS = %w[provider name active state health_status].freeze

    def self.run(token:, filters: {}, tenants: nil)
      new(token: token, filters: filters, tenants: tenants).run
    end

    def initialize(token:, filters: {}, tenants: nil)
      @token = token
      @tenants = tenants
      @filters = stringify(filters)
      unknown = @filters.keys - FILTERS
      raise Error, "unknown filter #{unknown.join(", ")}" if unknown.any?
    end

    def run
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rows = []
      Walk.each(token: @token, tenants: @tenants) do
        BankConnection.order(:id).each do |connection|
          next unless matches?(connection)

          rows << row_for(connection)
        end
      end
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)

      {
        bank_connections: rows,
        meta: {
          row_count: rows.length,
          query_time_ms: elapsed_ms
        }
      }
    end

    private

    def matches?(connection)
      @filters.all? { |name, value|
        stored = connection.public_send(name)
        stored.to_s.downcase == value.to_s.downcase
      }
    end

    def row_for(connection)
      ALLOWED.each_with_object("tenant" => Tenant.current) { |name, row|
        row[name] = connection.public_send(name)
      }
    end

    def stringify(filters)
      filters.to_h.transform_keys(&:to_s).except(
        "controller", "action", "format", "subdomain",
        "tenant", "tenants", "attributes")
    end
  end
end
