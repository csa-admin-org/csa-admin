module HasSeasons
  extend ActiveSupport::Concern

  included do
    validate :at_least_one_season
  end

  def seasons=(seasons)
    self[:seasons] = seasons & ACP.seasons
  end

  def all_seasons?
    seasons == ACP.seasons
  end

  def season_name
    seasons.map { |s| I18n.t "season.#{s}" }.to_sentence
  end

  def out_of_season_quantity(delivery)
    0 if Current.acp.seasons? && seasons.exclude?(delivery.season)
  end

  private

  def at_least_one_season
    if seasons.empty?
      errors.add(:seasons, :invalid)
    end
  end
end
