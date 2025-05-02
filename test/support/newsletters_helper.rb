# frozen_string_literal: true

module NewslettersHelper
  def build_newsletter(attributes = {})
    Newsletter.new({
      subject: "Hello",
      audience: "member_state::all",
      template: newsletter_templates(:dual)
    }.merge(attributes))
  end

  def create_newsletter(attributes = {})
    build_newsletter(attributes).tap(&:save!)
  end
end
