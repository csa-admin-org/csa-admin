class HalfdayPreset < ActiveRecord::Base
  include TranslatedAttributes
  include HalfdayNaming

  default_scope { order_by_place }

  translated_attributes :place, :place_url, :activity

  validates :places, presence: true, uniqueness: { scope: :activities }
  validates :activities, presence: true

  def name
    [place, activity].compact.join(', ')
  end
end
