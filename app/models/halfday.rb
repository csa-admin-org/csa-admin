class Halfday < ActiveRecord::Base
  include HasFiscalYearScopes
  include HalfdayNaming

  attr_accessor :preset_id

  has_many :participations, class_name: 'HalfdayParticipation'

  scope :coming, -> { where('halfdays.date > ?', Date.current) }
  scope :past, -> { where('halfdays.date <= ?', Date.current) }
  scope :past_current_year, -> {
    where('halfdays.date < ? AND halfdays.date >= ?', Date.current, Current.fy_range.min)
  }

  validates :date, :start_time, :end_time, presence: true
  validates :place, :activity, presence: true
  validates :participants_limit,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
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

  def self.available_for(member)
    where('date >= ?', 3.days.from_now)
      .includes(:participations)
      .reject { |hd| hd.participant?(member) || hd.full? }
      .sort_by { |hd| "#{hd.date}#{hd.period}" }
  end

  def full?
    participants_limit && missing_participants_count.zero?
  end

  def participant?(member)
    participations.map(&:member_id).include?(member.id)
  end

  def missing_participants_count
    participants_limit &&
      participants_limit - participations.sum(:participants_count)
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

  %i[place place_url activity].each do |attr|
    define_method attr do
      preset ? 'preset' : self[attr]
    end
  end

  def preset
    @preset ||= HalfdayPreset.find_by(id: preset_id)
  end

  private

  def end_time_must_be_greather_than_start_time
    if date && end_time <= start_time
      errors.add(:end_time, :invalid)
    end
  end

  def set_preset
    if preset
      self.place = preset.place
      self.place_url = preset.place_url
      self.activity = preset.activity
    end
  end

  def add_date_to_time(attr)
    return nil unless date && self[attr]
    (
      date.to_time(:utc) +
      self[attr].utc.strftime('%k').to_i.hours +
      self[attr].utc.strftime('%M').to_i.minutes
    ).in_time_zone
  end
end
