# frozen_string_literal: true

class PriceReductionCard < ApplicationRecord
  include TranslatedAttributes

  REQUIRED_FIELDS = %w[name number expires_on].freeze
  SENTENCE_DOWNCASE_LOCALES = %i[en fr it nl].freeze

  translated_attributes :name, required: true

  has_many :price_reductions
  has_many :member_cards, dependent: :restrict_with_exception

  validate :required_fields_selected

  def required_fields
    REQUIRED_FIELDS.select { |field| public_send("require_#{field}?") }
  end

  def required_fields=(fields)
    selected = Array(fields).compact_blank
    self.require_name = selected.include?("name")
    self.require_number = selected.include?("number")
    self.require_expires_on = selected.include?("expires_on")
  end

  def required_fields_sentence
    labels = required_fields.map { |field|
      self.class.human_attribute_name("required_field/#{field}")
    }
    return if labels.empty?

    if I18n.locale.to_sym.in?(SENTENCE_DOWNCASE_LOCALES)
      labels = [ labels.first, *labels.drop(1).map(&:downcase) ]
    end
    labels.to_sentence
  end

  def can_destroy?
    price_reductions.none? && member_cards.none?
  end

  private

  def required_fields_selected
    return if required_fields.any?

    errors.add(:required_fields, :no_required_field)
  end
end
