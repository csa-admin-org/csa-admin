# frozen_string_literal: true

module Activity::Presetable
  extend ActiveSupport::Concern

  included do
    attr_reader :preset_id, :preset
  end

  def preset_id=(preset_id)
    @preset_id = preset_id
    if @preset = ActivityPreset.find_by(id: preset_id)
      self.places = @preset.places
      self.place_urls = @preset.place_urls
      self.titles = @preset.titles
    end
  end

  %i[places place_urls titles].each do |attr|
    define_method attr do
      @preset ? Hash.new("preset") : self[attr]
    end
  end
end
