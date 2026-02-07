# frozen_string_literal: true

# Provides configuration for displaying basket contents on the member-facing
# deliveries page. When enabled, members can see the list of products (and
# optionally quantities) for their next delivery, subject to a configurable
# time window before the delivery date.
module Organization::BasketContentFeature
  extend ActiveSupport::Concern

  included do
    translated_attributes :basket_content_member_title, required: true
    translated_attributes :basket_content_member_note

    validates :basket_content_member_visible_hours_before,
      numericality: {
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 7 * 24,
        only_integer: true
      }

    before_create :set_basket_content_member_defaults
  end

  # Returns the Time at which basket contents become visible to members
  # for the given delivery. This is calculated as X hours before midnight
  # (00:00:00) on the delivery day in the organization's timezone.
  def basket_content_member_visible_at(delivery)
    delivery.date.in_time_zone(time_zone).beginning_of_day -
      basket_content_member_visible_hours_before.hours
  end

  # Returns true if the basket contents for the given delivery should
  # currently be shown to members, based on the configured time window.
  def basket_content_visible_for_delivery?(delivery)
    basket_content_member_visible?
      && basket_content_member_visible_at(delivery).past?
  end

  def default_basket_content_member_titles
    Organization.languages.index_with do |locale|
      I18n.with_locale(locale) {
        I18n.t("organization.default_basket_content_member_title")
      }
    end
  end

  def default_basket_content_member_notes
    Organization.languages.index_with do |locale|
      I18n.with_locale(locale) {
        I18n.t("organization.default_basket_content_member_note")
      }
    end
  end

  private

  def set_basket_content_member_defaults
    self.basket_content_member_titles = default_basket_content_member_titles
    self.basket_content_member_notes = default_basket_content_member_notes
  end
end
