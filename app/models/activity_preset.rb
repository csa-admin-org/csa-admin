class ActivityPreset < ApplicationRecord
  include TranslatedAttributes

  default_scope { order_by_place }

  translated_attributes :place, :title, required: true
  translated_attributes :place_url

  def name
    [place, title].compact.join(', ')
  end
end
