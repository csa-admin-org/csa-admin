# frozen_string_literal: true

module Organization::BasketContentFeature
  extend ActiveSupport::Concern

  included do
    translated_attributes :basket_content_member_title, required: { on: :update }
    translated_attributes :basket_content_member_note

    validates :basket_content_member_visible_hours_before,
      numericality: {
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 7 * 24,
        only_integer: true
      }

    before_create :set_basket_content_member_defaults
  end

  def basket_content_member_visible_at(delivery)
    delivery.date.in_time_zone(time_zone).beginning_of_day -
      basket_content_member_visible_hours_before.hours
  end

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
