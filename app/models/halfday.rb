class Halfday < ActiveRecord::Base
  include HasFiscalYearScopes

  attr_accessor :preset_id

  has_many :participations, class_name: 'HalfdayParticipation'

  scope :coming, -> { where('halfdays.date > ?', Date.current) }
  scope :available, -> { where('halfdays.date >= ?', 3.days.from_now) }
  scope :past, -> { where('halfdays.date <= ?', Date.current) }
  scope :past_current_year, -> {
    where('halfdays.date < ? AND halfdays.date >= ?', Date.current, Current.fy_range.min)
  }

  validates :date, :start_time, :end_time, presence: true
  validates :place, :activity, presence: true, unless: :use_preset?
  validate :end_time_must_be_greather_than_start_time

  before_create :set_preset

  def self.coming_dates_for_gribouille(member)
    today = Date.current
    coming_dates =
      Halfday.coming.where('date < ?', 3.weeks.from_now.to_date).order(:date)
    coming_dates.each_with_object([]) do |halfday, dates|
      break dates if dates.size == 8
      participation = member.halfday_participations.find_by(halfday: halfday)
      next unless halfday.date > today + 3.days || participation

      if participation
        dates << { halfday: halfday, participation: participation }
      elsif !halfday.full?
        dates << { halfday: halfday }
      end
      dates
    end
  end

  def full?
    participants_limit? && participations.map(&:participants_count).sum >= participants_limit
  end

  def participant?(member)
    participations.map(&:member_id).include?(member.id)
  end

  def name
    [I18n.l(date, format: :medium), place, period].join(', ')
  end

  def period
    [start_time, end_time].map { |t| t.strftime('%k:%M') }.join('-')
  end

  def start_time
    add_date_to_time(:start_time)
  end

  def end_time
    add_date_to_time(:end_time)
  end

  %i[place place_url activity].each do |preset|
    define_method preset do
      use_preset? ? 'preset' : self[preset]
    end
  end

  def use_preset?
    Preset.find(preset_id)
  end

  Preset = Struct.new(:id, :place, :place_url, :activity) do
    def self.all
      [
        new(1, 'Thielle', 'https://goo.gl/maps/xSxmiYRhKWH2', 'Aide aux champs'),
        new(2, 'Jardin de la Main', 'https://goo.gl/maps/tUQcLu1KkPN2', 'Confection des paniers')
      ]
    end

    def self.find(id)
      all.find { |p| p.id == id.to_i }
    end

    def name
      str = place
      str += ", #{activity}" if activity.present?
      str
    end
  end

  private

  def end_time_must_be_greather_than_start_time
    if end_time <= start_time
      errors.add(:end_time, :invalid)
    end
  end

  def set_preset
    if preset = Preset.find(preset_id)
      self.place = preset.place
      self.place_url = preset.place_url
      self.activity = preset.activity
    end
  end

  def add_date_to_time(attr)
    return nil unless self[attr]
    (
      date.to_time(:utc) +
      self[attr].utc.strftime('%k').to_i.hours +
      self[attr].utc.strftime('%M').to_i.minutes
    ).in_time_zone
  end
end
