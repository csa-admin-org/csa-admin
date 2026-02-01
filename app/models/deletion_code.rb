# frozen_string_literal: true

# Generates and verifies deterministic 6-digit codes for member deletion flow.
# Codes are tied to a specific session and expire after 15 minutes.
#
# The code is derived from:
# - session.id + session.updated_at + tenant + secret_key_base
#
# This ensures:
# - Codes are reproducible (deterministic)
# - Codes expire when session.updated_at changes or 15 minutes pass
# - Codes are tenant-specific
class DeletionCode
  EXPIRY = 15.minutes

  class << self
    def generate(session)
      digest(session, session.updated_at)
    end

    def verify(session, code)
      return false if code.blank?
      return false if session.updated_at < EXPIRY.ago

      expected = digest(session, session.updated_at)
      ActiveSupport::SecurityUtils.secure_compare(expected, code.to_s.strip)
    end

    private

    def digest(session, timestamp)
      data = [
        session.id,
        timestamp.to_i,
        Tenant.current,
        Rails.application.secret_key_base
      ].join("-")

      # Generate a 6-digit code from HMAC
      hmac = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, data)
      (hmac.to_i(16) % 1_000_000).to_s.rjust(6, "0")
    end
  end
end
