# frozen_string_literal: true

# Shared Action Text HTML helpers for email and public feed rendering.
# Unwraps attachment wrapper tags while keeping the nested preview HTML
# (same approach as Rails mailer sanitization for Trix gallery markup).
module ActionTextHtml
  module_function

  def unwrap_attachments(html)
    html.to_s
      .gsub(/<action-text-attachment\b[^>]*>/i, "")
      .gsub(%r{</action-text-attachment>}i, "")
  end
end
