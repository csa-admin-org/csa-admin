# frozen_string_literal: true

require "test_helper"

class Query::FilterParametersTest < ActiveSupport::TestCase
  test "sql is filtered from parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    assert_equal({ "sql" => "[FILTERED]" }, filter.filter("sql" => "SELECT * FROM members"))
  end

  test "member personal data is filtered from parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(
      member: {
        phones: "x",
        street: "x",
        zip: "x",
        city: "x",
        note: "x",
        food_note: "x",
        sepa_mandates_attributes: { "0" => { iban: "x", umr: "x" } }
      }
    )

    assert_equal({
      member: {
        phones: "[FILTERED]",
        street: "[FILTERED]",
        zip: "[FILTERED]",
        city: "[FILTERED]",
        note: "[FILTERED]",
        food_note: "[FILTERED]",
        sepa_mandates_attributes: { "0" => { iban: "[FILTERED]", umr: "[FILTERED]" } }
      }
    }, filtered)
  end
end
