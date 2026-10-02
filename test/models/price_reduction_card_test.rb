# frozen_string_literal: true

require "test_helper"

class PriceReductionCardTest < ActiveSupport::TestCase
  test "required fields sentence lists the selected fields" do
    card = PriceReductionCard.new(require_name: true, require_number: true, require_expires_on: false)

    assert_equal "Name and number", card.required_fields_sentence

    I18n.with_locale(:fr) do
      assert_equal "Nom et numéro", card.required_fields_sentence
    end

    I18n.with_locale(:de) do
      assert_equal "Name und Nummer", card.required_fields_sentence
    end
  end

  test "at least one field must be required" do
    card = PriceReductionCard.new(
      names: { "en" => "CarteCulture" },
      required_fields: [])

    assert_not card.valid?
    assert card.errors.added?(:required_fields, :no_required_field)
  end
end
