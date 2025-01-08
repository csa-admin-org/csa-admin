# frozen_string_literal: true

module EmailSuppressionsHelper
  def suppress_email(email, attributes = {})
    EmailSuppression.suppress!(email, **{
      stream_id: "outbound",
      origin: "Recipient",
      reason: "HardBounce"
    }.merge(attributes))
  end
end
