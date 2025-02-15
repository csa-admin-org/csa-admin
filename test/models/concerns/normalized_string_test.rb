# frozen_string_literal: true

require "test_helper"

class NormalizedStringTest < ActiveSupport::TestCase
  test "normalizes name" do
    model = Member.new(name: "  l’Aubier \n \r \t \u202F ")
    assert_equal "l'Aubier", model.name
  end
end
