# frozen_string_literal: true

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

      hmac = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, data)
      (hmac.to_i(16) % 1_000_000).to_s.rjust(6, "0")
    end
  end
end
