# frozen_string_literal: true

module BulkDatesInsert
  extend ActiveSupport::Concern

  included do
    attribute :bulk_dates_starts_on, :date
    attribute :bulk_dates_ends_on, :date
    attribute :bulk_dates_weeks_frequency, :integer
    attribute :bulk_dates_wdays, :json, default: []

    with_options if: :date? do
      validates :bulk_dates_starts_on, absence: true
      validates :bulk_dates_ends_on, absence: true
      validates :bulk_dates_weeks_frequency, absence: true
      validates :bulk_dates_wdays, absence: true
    end
    with_options unless: :date? do
      validates :bulk_dates_starts_on, presence: true
      validates :bulk_dates_starts_on, date: { before: :bulk_dates_ends_on }, if: :bulk_dates_ends_on
      validates :bulk_dates_ends_on, presence: true
      validates :bulk_dates_ends_on, date: {
        after: :bulk_dates_starts_on,
        before_or_equal_to: proc { |o| Current.org.fiscal_year_for(o.bulk_dates_starts_on).end_of_year }
      }, if: :bulk_dates_starts_on
      validates :bulk_dates_weeks_frequency, inclusion: { in: 1..4, allow_nil: true }, presence: true
      validates :bulk_dates_wdays, presence: true
      validate :bulk_dates_must_be_present
    end
  end

  def save(*args, **options, &block)
    if date?
      super
    elsif valid?
      run_callbacks(:save) {
        self.class.create bulk_attributes
        self.date = bulk_dates.first
      }
    end
  end

  def bulk_dates_wdays=(wdays)
    super wdays.map(&:to_i) & Array(0..6).map(&:to_i)
  end

  def bulk_dates
    return @dates if defined? @dates
    return if date?
    return unless bulk_dates_weeks_frequency
    return unless bulk_dates_starts_on
    return unless bulk_dates_ends_on

    d = bulk_dates_starts_on
    @dates = []

    while d <= bulk_dates_ends_on
      @dates << d if bulk_dates_wdays.include?(d.wday)
      if d.sunday?
        d = (d + bulk_dates_weeks_frequency.weeks).monday
      else
        d += 1.day
      end
    end

    @dates
  end

  private

  def bulk_dates_must_be_present
    errors.add(:bulk_dates_wdays, :invalid) unless bulk_dates.present?
  end

  def bulk_attributes
    attrs = attributes.except(*%w[
      id
      created_at
      updated_at
      bulk_dates_starts_on
      bulk_dates_ends_on
      bulk_dates_weeks_frequency
      bulk_dates_wdays
    ]).map { |k, v|
      [
        k,
        v.is_a?(Tod::TimeOfDay) ? v.to_s : v
      ]
    }.to_h
    bulk_dates.map { |date| attrs.merge("date" => date) }
  end
end
