# frozen_string_literal: true

module Organization::ActivityFeature
  extend ActiveSupport::Concern

  ACTIVITY_I18N_SCOPES = %w[
    hour_work
    halfday_work
    day_work
    basket_preparation
  ]
  ACTIVITY_PARTICIPATIONS_DEMANDED_LOGIC_DEFAULT = <<-LIQUID
    {% if member.salary_basket %}
      0
    {% else %}
      {{ membership.baskets | divided_by: membership.full_year_deliveries | times: membership.full_year_activity_participations | round }}
    {% endif %}
  LIQUID

  included do
    attribute :activity_participations_demanded_logic, :string, default: -> {
      ACTIVITY_PARTICIPATIONS_DEMANDED_LOGIC_DEFAULT
    }

    translated_attributes :activity_participations_form_detail

    validates :activity_i18n_scope, inclusion: { in: -> { ACTIVITY_I18N_SCOPES } }
    validates :activity_participation_deletion_deadline_in_days,
      numericality: { greater_than_or_equal_to: 1, allow_nil: true }
    validates :activity_availability_limit_in_days,
      numericality: { greater_than_or_equal_to: 0 }
    validates :activity_price,
      numericality: { greater_than_or_equal_to: 0 }
    validates :activity_participations_form_min, :activity_participations_form_max,
      numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :activity_participations_form_step,
      numericality: { greater_than_or_equal_to: 1 }, presence: true
    validate :activity_participations_demanded_logic_must_be_valid
  end

  class_methods do
    def activity_i18n_scopes = ACTIVITY_I18N_SCOPES
    def activity_participations_demanded_logic_default = ACTIVITY_PARTICIPATIONS_DEMANDED_LOGIC_DEFAULT
  end

  def activity_participations_form?
    activity_participations_form_min || activity_participations_form_max
  end

  def activity_phone=(phone)
    super PhonyRails.normalize_number(phone, default_country_code: country_code)
  end

  def activity_phone
    super.presence&.phony_formatted(format: :international)
  end

  private

  def activity_participations_demanded_logic_must_be_valid
    Liquid::Template.parse(activity_participations_demanded_logic)
  rescue Liquid::SyntaxError => e
    errors.add(:activity_participations_demanded_logic, e.message)
  end
end
