# frozen_string_literal: true

module Organization::AbsenceFeature
  extend ActiveSupport::Concern

  ABSENCES_INCLUDED_MODES = %w[provisional_absence provisional_delivery].freeze
  ABSENCES_INCLUDED_LOGIC_DEFAULT = <<~LIQUID
    {{ membership.baskets | divided_by: membership.full_year_deliveries | times: membership.full_year_absences_included | round }}
  LIQUID

  included do
    translated_rich_texts :absence_extra_text

    attribute :absences_included_logic, :string, default: -> {
      ABSENCES_INCLUDED_LOGIC_DEFAULT
    }

    validates :absence_notice_period_in_days,
      numericality: { greater_than_or_equal_to: 1 }
    validates :basket_shifts_annually,
      numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :basket_shift_deadline_in_weeks,
      numericality: { greater_than_or_equal_to: 1, allow_nil: true }
    validates :absences_included_mode,
      presence: true,
      inclusion: { in: ABSENCES_INCLUDED_MODES }
    validates :absences_included_reminder_weeks_before,
      presence: true,
      numericality: { greater_than_or_equal_to: 1 }
    validates :absences_included_logic, presence: true
    validate :absences_included_logic_must_be_valid
  end

  class_methods do
    def absences_included_logic_default = ABSENCES_INCLUDED_LOGIC_DEFAULT
  end

  def basket_shift_enabled?
    absences_billed? && basket_shifts_annually != 0
  end

  def basket_shift_annual_limit?
    basket_shifts_annually&.positive?
  end

  def basket_shift_deadline_enabled?
    basket_shift_deadline_in_weeks.present?
  end

  def basket_shift_allowed_range_for(basket)
    return unless basket_shift_deadline_enabled?

    absence = basket.absence
    return unless absence

    deadline = basket_shift_deadline_in_weeks.weeks
    ([ absence.started_on - deadline, Date.tomorrow ].max)..(absence.ended_on + deadline)
  end

  def absences_included_provisional_absence_mode?
    absences_included_mode == "provisional_absence"
  end

  def absences_included_provisional_delivery_mode?
    absences_included_mode == "provisional_delivery"
  end

  def absences_included_reminder_period
    absences_included_reminder_weeks_before.weeks
  end

  def absence_notice_period_limit_on
    absence_notice_period_in_days.days.from_now.beginning_of_day.to_date
  end

  def within_absence_notice_period?(date)
    date > absence_notice_period_limit_on
  end

  private

  def absences_included_logic_must_be_valid
    return if absences_included_logic.blank?

    Liquid::Template.parse(absences_included_logic)
  rescue Liquid::SyntaxError => e
    errors.add(:absences_included_logic, e.message)
  end
end
