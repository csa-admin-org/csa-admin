# frozen_string_literal: true

class ActivityPreset < ApplicationRecord
  include TranslatedAttributes

  translated_attributes :place, :title, required: true
  translated_attributes :place_url

  validates :places, uniqueness: { scope: :titles }

  def name
    [ place, title ].compact.join(", ")
  end
end
