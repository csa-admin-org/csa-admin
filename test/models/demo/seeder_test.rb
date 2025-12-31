# frozen_string_literal: true

require "test_helper"

class Demo::SeederTest < ActiveSupport::TestCase
  test "raises error when not in demo tenant" do
    error = assert_raises(RuntimeError) do
      Demo::Seeder.new
    end

    assert_equal "Demo::Seeder can only run in a demo tenant", error.message
  end
end
