class ActivityPreset < ActiveRecord::Base
  include TranslatedAttributes

  default_scope { order_by_place }

  translated_attributes :place, :place_url, :title

  validates :places, presence: true, uniqueness: { scope: :titles }
  validates :titles, presence: true

  def name
    [place, title].compact.join(', ')
  end
end
