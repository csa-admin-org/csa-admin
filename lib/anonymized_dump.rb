# frozen_string_literal: true

module AnonymizedDump
  class Error < StandardError; end

  TENANT_FORMAT = /\A[a-z][a-z0-9-]*\z/
  DISPOSABLE_EMAIL_DOMAIN = "mailinator.com"

  def self.tenant_name!(tenant)
    name = tenant.to_s
    return name if name.match?(TENANT_FORMAT) && !name.include?("--")

    raise Error, "invalid tenant name #{tenant.inspect}"
  end
end
