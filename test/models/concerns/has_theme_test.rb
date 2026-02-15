# frozen_string_literal: true

require "test_helper"

class HasThemeTest < ActiveSupport::TestCase
  class DummyClass
    include ActiveModel::Model
    include ActiveModel::Attributes

    include HasTheme
  end

  test "sets default theme to system" do
    test_model = DummyClass.new
    assert_equal "system", test_model.theme
  end

  test "validates theme presence" do
    test_model = DummyClass.new
    test_model.theme = nil
    assert_not test_model.valid?
    assert_includes test_model.errors[:theme], "can't be blank"
  end

  test "validates theme inclusion" do
    test_model = DummyClass.new
    test_model.theme = "invalid"
    assert_not test_model.valid?
    assert_includes test_model.errors[:theme], "is not included in the list"
  end

  test "accepts valid themes" do
    %w[system light dark].each do |theme|
      test_model = DummyClass.new
      test_model.theme = theme
      assert test_model.valid?, "Expected theme '#{theme}' to be valid"
    end
  end
end
