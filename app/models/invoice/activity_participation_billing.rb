# frozen_string_literal: true

module Invoice::ActivityParticipationBilling
  extend ActiveSupport::Concern

  included do
    scope :activity_participations_fiscal_year, ->(year) {
      activity_participation_type
        .where(missing_activity_participations_fiscal_year: Current.org.fiscal_year_for(year).year)
    }

    before_validation :set_missing_activity_participations, on: :create, if: :activity_participation_type?

    validates :missing_activity_participations_count,
      numericality: { greater_than_or_equal_to: 1, allow_blank: true }
    validates :missing_activity_participations_count,
      absence: true,
      unless: :activity_participation_type?
    validates :items, absence: true, if: :activity_participation_type?
    validates :activity_price,
      numericality: { greater_than_or_equal_to: 1 },
      if: :missing_activity_participations_count,
      on: :create
    validates :missing_activity_participations_fiscal_year,
      numericality: true,
      inclusion: { in: -> { Current.org.fiscal_years } },
      if: :missing_activity_participations_count,
      on: :create

    after_commit :update_membership_activity_participations_accepted!
  end

  def missing_activity_participations_fiscal_year=(year)
    super Current.org.fiscal_year_for(year).year
  end

  def missing_activity_participations_fiscal_year
    Current.org.fiscal_year_for(super)
  end

  def missing_activity_participations_count=(number)
    return if number.blank?

    super
    self[:entity_type] = "ActivityParticipation" unless entity_type?
  end

  private

  def set_missing_activity_participations
    if ActivityParticipation === entity
      self.member = entity.member
      self.missing_activity_participations_fiscal_year = entity.activity.fiscal_year
      self.missing_activity_participations_count = entity.participants_count
    end
  end

  def update_membership_activity_participations_accepted!
    if activity_participation_type?
      member.membership(missing_activity_participations_fiscal_year)&.update_activity_participations_accepted!
    end
  end
end
