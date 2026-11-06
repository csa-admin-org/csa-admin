# frozen_string_literal: true

require "test_helper"

class ShopProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    login admins(:super)
  end

  test "new form has one editor per translated description" do
    france_org

    get new_shop_product_path

    assert_response :success
    names = css_select("lexxy-editor").map { |editor| editor["name"] }
    assert_equal [ "shop_product[description_fr]" ], names
  end

  test "create with a French description does not hit the rich text unique index" do
    france_org

    assert_difference -> { Shop::Product.count }, 1 do
      post shop_products_path, params: {
        shop_product: {
          name_fr: "Pommes",
          description_fr: "<p>Des pommes du verger</p>",
          available: "1",
          display_in_delivery_sheets: "0",
          producer_id: "",
          available_for_depot_ids: [ "", depots(:farm).id.to_s ],
          available_for_delivery_ids: [ "", deliveries(:thursday_1).id.to_s ],
          variants_attributes: {
            "0" => {
              name_fr: "1 kg",
              price: "7",
              stock: "4",
              weight_in_kg: "",
              basket_complement_id: "",
              available: "1"
            }
          }
        }
      }
    end

    product = Shop::Product.order(:id).last
    assert_equal "Pommes", product.name_fr
    assert_equal 1, ActionText::RichText.where(record: product, name: "description_fr").count
    assert_includes product.rich_text_description_fr.to_plain_text, "pommes"
  end

  private

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end
