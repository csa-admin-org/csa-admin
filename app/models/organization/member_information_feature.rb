# frozen_string_literal: true

module Organization::MemberInformationFeature
  extend ActiveSupport::Concern

  included do
    translated_rich_texts :member_information_text,
      required: -> { feature?("member_information") }
    translated_attributes :member_information_title
  end

  def member_information?
    feature?("member_information")
  end
end
