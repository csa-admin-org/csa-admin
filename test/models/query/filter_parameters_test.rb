# frozen_string_literal: true

require "test_helper"

class Query::FilterParametersTest < ActiveSupport::TestCase
  test "sql is filtered from parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    assert_equal({ "sql" => "[FILTERED]" }, filter.filter("sql" => "SELECT * FROM members"))
  end
end
