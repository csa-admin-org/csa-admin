class HalfdayPreset < ActiveRecord::Base
  default_scope { order(:place) }

  validates :place, presence: true, uniqueness: { scope: :activity }
  validates :activity, presence: true
  validates :place_url, format: { with: /\Ahttp.*/i, allow_blank: true }

  def name
    [place, activity].compact.join(', ')
  end
end
