# frozen_string_literal: true

require "test_helper"

class HasCurrencyTest < ActiveSupport::TestCase
  class DummyClass
    include ActiveModel::Model
    include ActiveModel::Attributes

    include HasCurrency
  end

  test "sets default currency_code from Current.org.currency_code" do
    test_model = DummyClass.new
    assert_equal Current.org.currency_code, test_model.currency_code
  end

  test "validates currency_code presence" do
    test_model = DummyClass.new
    test_model.currency_code = nil
    assert_not test_model.valid?
    assert_includes test_model.errors[:currency_code], "can't be blank"
  end

  test "validates currency_code format" do
    test_model = DummyClass.new
    test_model.currency_code = "XYZ"
    assert_not test_model.valid?
    assert_includes test_model.errors[:currency_code], "is not included in the list"
  end
end
