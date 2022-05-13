class Activity < ApplicationRecord
  include TranslatedAttributes
  include HasFiscalYearScopes
  include BulkDatesInsert

  attr_reader :preset_id, :preset

  attribute :start_time, :time_only
  attribute :end_time, :time_only

  translated_attributes :place_url, :description
  translated_attributes :place, :title, required: true

  has_many :participations, class_name: 'ActivityParticipation'

  scope :ordered, ->(order) { order(date: order, start_time: :asc) }
  scope :coming, -> { where('activities.date >= ?', Date.current) }
  scope :past, -> { where('activities.date <= ?', Date.current) }
  scope :past_current_year, -> {
    where('activities.date < ? AND activities.date >= ?', Date.current, Current.fy_range.min)
  }
  scope :without_participations, -> {
    includes(:participations).where(participations: { id: nil })
  }

  validates :start_time, :end_time, presence: true
  validates :participants_limit,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validate :end_time_must_be_greather_than_start_time
  validate :period_duration_must_one_hour

  def self.available_for(member)
    where('date >= ?', Current.acp.activity_availability_limit_in_days.days.from_now)
      .ordered(:asc)
      .includes(:participations)
      .reject { |hd| hd.participant?(member) }
  end

  def self.available
    where('date >= ?', Current.acp.activity_availability_limit_in_days.days.from_now)
      .ordered(:asc)
      .includes(:participations)
      .reject(&:full?)
  end

  def full?
    participants_limit && missing_participants_count.zero?
  end

  def participant?(member)
    participations.map(&:member_id).include?(member.id)
  end

  def participants_count
    participations.map(&:participants_count).sum
  end

  def missing_participants_count
    participants_limit && participants_limit - participants_count
  end

  def name(show_place: true)
    parts = [I18n.l(date, format: :medium), period]
    parts << place if show_place
    parts.join(', ')
  end

  def period
    [start_time, end_time].map { |t| t.strftime('%-k:%M') }.join('-')
  end

  %i[places place_urls titles].each do |attr|
    define_method attr do
      @preset ? Hash.new('preset') : self[attr]
    end
  end

  def preset_id=(preset_id)
    @preset_id = preset_id
    if @preset = ActivityPreset.find_by(id: preset_id)
      self.places = @preset.places
      self.place_urls = @preset.place_urls
      self.titles = @preset.titles
    end
  end

  def can_destroy?
    participations.none?
  end

  private

  def end_time_must_be_greather_than_start_time
    if end_time && start_time && end_time <= start_time
      errors.add(:end_time, :invalid)
    end
  end

  def period_duration_must_one_hour
    if Current.acp.activity_i18n_scope == 'hour_work' &&
        (end_time - start_time).to_i != 1.hour
      errors.add(:end_time, :must_be_one_hour)
    end
  end
end
