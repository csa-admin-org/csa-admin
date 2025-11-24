# frozen_string_literal: true

module Organization::AbsenceFeature
  extend ActiveSupport::Concern

  included do
    translated_rich_texts :absence_extra_text

    validates :absence_notice_period_in_days,
      numericality: { greater_than_or_equal_to: 1 }
    validates :basket_shifts_annually,
      numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :basket_shift_deadline_in_weeks,
      numericality: { greater_than_or_equal_to: 1, allow_nil: true }
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
end
