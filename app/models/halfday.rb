class Halfday < ActiveRecord::Base
  include TranslatedAttributes
  include HasFiscalYearScopes
  include HalfdayNaming

  attr_reader :preset_id, :preset

  translated_attributes :place, :place_url, :activity, :description

  has_many :participations, class_name: 'HalfdayParticipation'

  scope :coming, -> { where('halfdays.date > ?', Date.current) }
  scope :past, -> { where('halfdays.date <= ?', Date.current) }
  scope :past_current_year, -> {
    where('halfdays.date < ? AND halfdays.date >= ?', Date.current, Current.fy_range.min)
  }

  validates :date, :start_time, :end_time, presence: true
  validates :participants_limit,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validate :end_time_must_be_greather_than_start_time

  def self.available_for(member)
    where('date >= ?', 3.days.from_now)
      .includes(:participations)
      .reject { |hd| hd.participant?(member) || hd.full? }
      .sort_by { |hd| "#{hd.date}#{hd.period}" }
  end

  def self.available
    where('date >= ?', 3.days.from_now)
      .includes(:participations)
      .reject(&:full?)
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
      participants_limit - participations.map(&:participants_count).sum
  end

  def name
    [I18n.l(date, format: :medium), place, period].join(', ')
  end

  def period
    [start_time, end_time].map { |t| t.strftime('%-k:%M') }.join('-')
  end

  def start_time
    add_date_to_time(:start_time)
  end

  def end_time
    add_date_to_time(:end_time)
  end

  %i[places place_urls activities].each do |attr|
    define_method attr do
      @preset ? Hash.new('preset') : self[attr]
    end
  end

  def preset_id=(preset_id)
    @preset_id = preset_id
    if @preset = HalfdayPreset.find_by(id: preset_id)
      self.places = @preset.places
      self.place_urls = @preset.place_urls
      self.activities = @preset.activities
    end
  end

  private

  def end_time_must_be_greather_than_start_time
    if date && end_time <= start_time
      errors.add(:end_time, :invalid)
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
