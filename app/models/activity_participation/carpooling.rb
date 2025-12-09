# frozen_string_literal: true

module ActivityParticipation::Carpooling
  extend ActiveSupport::Concern

  included do
    attr_reader :carpooling

    scope :carpooling, -> { where.not(carpooling_phone: nil) }

    with_options on: :create, if: :carpooling do
      validates_plausible_phone :carpooling_phone, country_code: "CH"
      validates :carpooling_phone, presence: true
      validates :carpooling_city, presence: true
    end

    before_validation :reset_carpooling_data, on: :create, unless: :carpooling
  end

  def carpooling_participations
    @carpooling_participations ||= self.class
      .where(activity_id: activity_id)
      .where.not(member_id: member_id)
      .carpooling
      .includes(:member)
  end

  def carpooling_phone=(phone)
    super PhonyRails.normalize_number(phone,
      default_country_code: Current.org.country_code)
  end

  def carpooling_phone
    super&.phony_formatted(format: :international)
  end

  def carpooling=(boolean)
    @carpooling = ActiveRecord::Type::Boolean.new.cast(boolean)
  end

  def carpooling?
    carpooling_phone.present?
  end

  private

  def reset_carpooling_data
    self.carpooling_phone = nil
    self.carpooling_city = nil
  end
end
