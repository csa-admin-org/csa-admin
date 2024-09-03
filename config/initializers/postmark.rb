# frozen_string_literal: true

module Postmark
  extend self

  def webhook_token
    sha = Digest::SHA256.new
    sha << Rails.application.secret_key_base
    sha << Tenant.current
    sha.hexdigest
  end

  def webhook_url
    Rails.application.routes.url_helpers.postmark_webhooks_url(
      host: "admin.#{Current.org.email_hostname}",
      protocol: "https")
  end
end
