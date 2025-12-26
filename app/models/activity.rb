# frozen_string_literal: true

class Activity < ApplicationRecord
  include HasDate
  include HasFiscalYear
  include TranslatedAttributes
  include BulkDatesInsert
  include Availability, Presetable

  attribute :start_time, :time_only
  attribute :end_time, :time_only

  translated_attributes :place_url, :description
  translated_attributes :place, :title, required: true

  has_many :participations, class_name: "ActivityParticipation"

  validates :start_time, :end_time, presence: true
  validates :participants_limit,
    numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  validate :end_time_must_be_greather_than_start_time
  validate :period_duration_must_one_hour

  scope :ordered, ->(order) { order(date: order, start_time: :asc) }

  def display_name
    name
  end

  def name(show_place: true)
    parts = [ I18n.l(date, format: :medium), period ]
    parts << place if show_place
    parts.join(", ")
  end

  def period
    [ start_time, end_time ].map { |t| t.strftime("%-k:%M") }.join("-")
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
    if Current.org.activity_i18n_scope == "hour_work" &&
        (end_time - start_time).to_i != 1.hour
      errors.add(:end_time, :must_be_one_hour)
    end
  end
end
