# frozen_string_literal: true

require "test_helper"

class HasPublicNameTest < ActiveSupport::TestCase
  test "without admin name" do
    object = basket_sizes(:small)

    object.update!(
      public_name_en: "Small",
      admin_name_en: "")

    assert_equal "Small", object.name
    assert_equal "Small", object.public_name
    assert_equal({ "en" => "Small" }, object[:names])
    assert_equal({ "en" => nil }, object[:public_names])
    assert_equal({ "en" => nil }, object.admin_names)
    assert_equal({}, object[:admin_names])
  end

  test "with admin name" do
    object = basket_sizes(:small)
    object.update!(
      public_name_en: "Small",
      admin_name_en: "SM")

    assert_equal "SM", object.name
    assert_equal "Small", object.public_name
    assert_equal({ "en" => "SM" }, object[:names])
    assert_equal({ "en" => "Small" }, object[:public_names])
    assert_equal({ "en" => "SM" }, object.admin_names)
    assert_equal({}, object[:admin_names])
  end
end
