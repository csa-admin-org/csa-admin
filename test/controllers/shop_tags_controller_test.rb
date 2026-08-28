# frozen_string_literal: true

require "test_helper"

class ShopTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    login admins(:super)
  end

  test "new form renders emoji picker left of names" do
    get new_shop_tag_path

    assert_response :success
    assert_select ".single-line.shop-tag-fields" do
      assert_select "li.shop-tag-emoji[data-controller='shop-tag-emoji']" do
        assert_select "input#shop_tag_emoji[type='hidden'][name='shop_tag[emoji]'][data-shop-tag-emoji-target='input']"
        assert_select "button.shop-tag-emoji-button.is-empty[data-shop-tag-emoji-target='button']"
        assert_select ".shop-tag-emoji-placeholder svg"
        assert_select ".shop-tag-emoji-grid[data-shop-tag-emoji-target='grid']" do
          assert_select "button.shop-tag-emoji-clear[data-value=?]", "" do
            assert_select "svg"
          end
          assert_select "button.shop-tag-emoji-cell", text: "🥕"
          assert_select "button.shop-tag-emoji-cell", text: "🌰"
          assert_select "button.shop-tag-emoji-cell", text: "🍋‍🟩"
          assert_select "button.shop-tag-emoji-cell", text: "🫜"
          assert_select "button.shop-tag-emoji-cell", text: "🎁"
          assert_select "button.shop-tag-emoji-cell", text: "❗"
          assert_select "button.shop-tag-emoji-cell", text: "⚕️"
        end
      end
      assert_select "div.is-grow input#shop_tag_name_en[name='shop_tag[name_en]']"
    end
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end
