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

  test "create a kilogram variant" do
    assert_difference -> { Shop::Product.count }, 1 do
      post shop_products_path, params: {
        shop_product: {
          name_en: "Potatoes",
          available: "1",
          variants_attributes: {
            "0" => {
              name_en: "Bulk",
              unit: "kg",
              price: "2.5",
              stock: "1.25",
              weight_in_kg: "0.5",
              available: "1"
            }
          }
        }
      }
    end

    variant = Shop::Product.order(:id).last.variants.sole
    assert_equal "kg", variant.unit
    assert_equal "1.25".to_d, variant.stock
    assert_nil variant.weight_in_kg
  end

  test "edit form shows the unit select and the kilogram price suffix" do
    shop_product_variants(:flour_wheat).update!(unit: "kg")

    get edit_shop_product_path(shop_products(:flour))

    assert_response :success
    assert_select "select[name*='[unit]'] option[value='kg'][selected]"
    assert_select "fieldset[data-controller='price-unit-suffix'] [data-price-unit-suffix-target='text']", minimum: 2
    assert_includes response.body, "/kg"
    assert_select "label[data-price-unit-suffix-target='stockLabel']",
      text: Shop::ProductVariant.human_attribute_name("stock/kg")
  end

  test "edit form disables the unit select once the variant has an order" do
    variant = shop_product_variants(:flour_wheat)
    create_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:flour).id,
        product_variant_id: variant.id,
        quantity: 1
      }
    })

    get edit_shop_product_path(shop_products(:flour))

    assert_response :success
    assert_select "select[name*='[unit]'][disabled]"
    assert_select "p.inline-hints", text: I18n.t("formtastic.hints.shop/product_variant.unit")
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
