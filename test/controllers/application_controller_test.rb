# frozen_string_literal: true

require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  # InvalidType is raised during format negotiation inside process_action,
  # before rescue_from handlers run — so we need to test it explicitly.

  test "invalid Accept header on admin side returns 415" do
    host! "admin.acme.test"

    get login_path, headers: { "Accept" => "y6U6D" }

    assert_response :unsupported_media_type
  end

  test "invalid Accept header on members side returns 415" do
    host! "members.acme.test"

    get members_login_path, headers: { "Accept" => "k0dZi" }

    assert_response :unsupported_media_type
  end

  test "SQL injection in Accept header on members side returns 415" do
    host! "members.acme.test"

    get members_login_path, headers: { "Accept" => "XOR(if(now()=sysdate(),sleep(15),0))XOR" }

    assert_response :unsupported_media_type
  end
end
