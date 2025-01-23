# frozen_string_literal: true

require "test_helper"

class Members::NewsletterSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
  end

  test "unsubscribe with get request (List-Unsubscribe-Post)" do
    token = Newsletter::Audience.encrypt_email("john@doe.com")
    assert_difference "EmailSuppression.active.count", 1 do
      get "/newsletters/unsubscribe/#{token}"
    end

    assert_response :success
  end

  test "unsubscribe with invalid token" do
    token = "invalid"
    assert_no_difference "EmailSuppression.active.count" do
      get "/newsletters/unsubscribe/#{token}"
    end

    assert_response :not_found
  end

  test "unsubscribe with POST request (List-Unsubscribe-Post)" do
    token = Newsletter::Audience.encrypt_email("john@doe.com")
    assert_difference "EmailSuppression.active.count", 1 do
      post "/newsletters/unsubscribe/#{token}/post"
    end

    assert_response :success
  end

  test "subscribe back" do
    token = Newsletter::Audience.encrypt_email("john@doe.com")
    get "/newsletters/unsubscribe/#{token}"

    assert_difference "EmailSuppression.active.count", -1 do
      post "/newsletters/subscribe/#{token}"
    end

    assert_response :success
  end
end
