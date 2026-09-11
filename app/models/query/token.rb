# frozen_string_literal: true

module Query
  class Token
    attr_reader :name, :secret, :tenants

    def self.authenticate(raw)
      return unless raw.present?

      entries.find { |token|
        ActiveSupport::SecurityUtils.secure_compare(token.secret, raw.to_s)
      }
    end

    def self.entries
      Rails.application.credentials.query.to_h.filter_map { |name, attrs|
        next unless attrs.is_a?(Hash)

        attrs = attrs.with_indifferent_access
        secret = attrs[:token].presence
        next unless secret.present?

        new(name: name.to_s, secret: secret.to_s, tenants: attrs[:tenants])
      }
    end

    def initialize(name:, secret:, tenants:)
      @name = name
      @secret = secret
      @tenants = tenants
    end

    def allows?(tenant)
      slug = tenant.to_s
      return false if Tenant::DEMO_TENANT_PATTERN.match?(slug) && !explicit?(slug)

      wildcard? || explicit?(slug)
    end

    def wildcard?
      tenants == "*"
    end

    def catalog_tenants
      wildcard? ? [ "*" ] : Array(tenants).map(&:to_s)
    end

    private

    def explicit?(slug)
      Array(tenants).map(&:to_s).include?(slug)
    end
  end
end
