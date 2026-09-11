# frozen_string_literal: true

require "test_helper"

class Query::TokenTest < ActiveSupport::TestCase
  test "wildcard allows production tenants but not demo unless listed" do
    token = Query::Token.new(name: "bot", secret: "s", tenants: "*")

    assert token.allows?("acme")
    assert_not token.allows?("demo-en")
    assert_equal [ "*" ], token.catalog_tenants
  end

  test "explicit list allows those tenants only" do
    token = Query::Token.new(name: "bot", secret: "s", tenants: [ "acme" ])

    assert token.allows?("acme")
    assert_not token.allows?("beta")
    assert_equal [ "acme" ], token.catalog_tenants
  end

  test "demo tenant allowed only when listed" do
    token = Query::Token.new(name: "bot", secret: "s", tenants: [ "demo-en" ])

    assert token.allows?("demo-en")
  end

  test "entries reads credentials hash" do
    creds = { "grok-bot" => { token: "abc", tenants: "*" } }
    Rails.application.credentials.stub(:query, creds) do
      entries = Query::Token.entries
      assert_equal 1, entries.size
      assert_equal "grok-bot", entries.first.name
      assert_equal "abc", entries.first.secret
    end
  end

  test "authenticate compares secrets" do
    token = Query::Token.new(name: "bot", secret: "secret-token", tenants: "*")
    Query::Token.stub(:entries, [ token ]) do
      assert_equal "bot", Query::Token.authenticate("secret-token").name
      assert_nil Query::Token.authenticate("wrong")
    end
  end
end
