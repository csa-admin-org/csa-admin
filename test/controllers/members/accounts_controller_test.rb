# frozen_string_literal: true

require "test_helper"

class Members::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
    session
  end

  def login_as_admin_originated(member, admin: admins(:ultra))
    session = Session.create!(
      admin: admin,
      member: member,
      email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
    session
  end

  test "edit renders for an admin-originated session" do
    login_as_admin_originated(members(:john))

    get edit_members_account_path

    assert_response :success
    assert_select "form[action='#{members_account_path}']"
    assert_select ".member-read-only-banner span",
      text: I18n.t("members.read_only_sessions.alert")
    assert_select ".member-read-only-banner form[action='#{members_logout_path}'] button[aria-label='#{I18n.t("layouts.members.header.logout")}']"
    assert_select ".member-read-only-banner .member-logout-label", false
  end

  test "update is blocked for an admin-originated session" do
    member = members(:john)
    login_as_admin_originated(member)

    assert_no_changes -> { member.reload.name } do
      patch members_account_path,
        params: { member: { name: "John Updated" } },
        headers: { "HTTP_REFERER" => edit_members_account_path }
    end

    assert_redirected_to edit_members_account_path
    assert_equal I18n.t("members.read_only_sessions.alert"), flash[:alert]
  end

  test "update is allowed for an admin-originated session in development" do
    member = members(:john)
    login_as_admin_originated(member)

    with_rails_env("development") do
      get edit_members_account_path
      assert_response :success
      assert_select ".member-read-only-banner", count: 0

      assert_changes -> { member.reload.name }, to: "John Updated" do
        patch members_account_path, params: {
          member: { name: "John Updated" }
        }
      end
    end

    assert_redirected_to members_account_path
  end

  test "update is allowed for an admin-originated session on a demo tenant" do
    member = members(:john)
    login_as_admin_originated(member)

    Tenant.stub(:demo?, true) do
      get edit_members_account_path
      assert_response :success
      assert_select ".member-read-only-banner", count: 0

      assert_changes -> { member.reload.name }, to: "John Updated" do
        patch members_account_path, params: {
          member: { name: "John Updated" }
        }
      end
    end

    assert_redirected_to members_account_path
  end

  test "show lists the current reduction card on one line" do
    travel_to "2024-06-01"
    org(features: Current.org.features | [ "price_reductions" ])
    member = members(:john)
    card_type = grant_card_reduction!(member, names: { "en" => "Caritas" })
    unused = PriceReductionCard.create!(
      names: { "en" => "Culture card" },
      require_name: false,
      require_number: true,
      require_expires_on: false)
    MemberCard.create!(
      member: member,
      price_reduction_card: card_type,
      name: "John",
      number: "QA-0006",
      expires_on: Date.new(2026, 9, 30))
    MemberCard.create!(
      member: member,
      price_reduction_card: unused,
      number: "CC-4242")
    login(member)

    get members_account_path

    assert_response :success
    assert_select ".account-row", text: /Card: Caritas/ do
      assert_select ".is-muted", text: "•••0006"
    end
    assert_select ".account-row", text: /Cards/, count: 0
    assert_select ".account-row", text: /Culture card/, count: 0
    assert_select ".account-row", text: /2026/, count: 0
  end

  test "edit renders only the card required by the current reduction" do
    travel_to "2024-06-01"
    org(features: Current.org.features | [ "price_reductions" ])
    member = members(:john)
    grant_card_reduction!(member, names: { "en" => "Caritas" })
    PriceReductionCard.create!(
      names: { "en" => "Culture card" },
      require_name: true,
      require_number: true,
      require_expires_on: true)
    login(member)

    get edit_members_account_path

    assert_response :success
    assert_select "fieldset#card"
    assert_select "legend.form-label", text: "Card: Caritas"
    assert_select "legend.form-label", text: /Culture card/, count: 0
    assert_select ".reduction-card-copy",
      text: I18n.t("members.accounts.cards.hint")
    assert_select "input[name='member[member_cards_attributes][][name]'][required]"
    assert_select "input[name='member[member_cards_attributes][][number]'][required]"
    assert_select "input[name='member[member_cards_attributes][][expires_on]']", count: 0
  end

  test "edit hides card fields when the current reduction has no card" do
    travel_to "2024-06-01"
    org(features: Current.org.features | [ "price_reductions" ])
    PriceReductionCard.create!(
      names: { "en" => "Culture card" },
      require_name: true,
      require_number: true,
      require_expires_on: true)
    login(members(:john))

    get edit_members_account_path

    assert_response :success
    assert_select "fieldset.reduction-card", count: 0
    assert_select "input[name='member[member_cards_attributes][][name]']", count: 0
  end

  test "update saves the current reduction card and ignores a posted type or id" do
    travel_to "2024-06-01"
    org(features: Current.org.features | [ "price_reductions" ])
    member = members(:john)
    card_type = grant_card_reduction!(member, names: { "en" => "Caritas" })
    unused = PriceReductionCard.create!(
      names: { "en" => "Culture card" },
      require_name: true,
      require_number: true,
      require_expires_on: false)
    current = MemberCard.create!(
      member: member,
      price_reduction_card: card_type,
      name: "John",
      number: "QA-0001")
    other = MemberCard.create!(
      member: member,
      price_reduction_card: unused,
      name: "Kept",
      number: "CC-4242")
    login(member)

    patch members_account_path, params: {
      member: {
        name: member.name,
        member_cards_attributes: [
          {
            id: other.id,
            price_reduction_card_id: unused.id,
            name: "Retyped",
            number: "CC-99"
          }
        ]
      }
    }

    assert_redirected_to members_account_path
    other.reload
    assert_equal unused.id, other.price_reduction_card_id
    assert_equal "CC-4242", other.number
    current.reload
    assert_equal card_type.id, current.price_reduction_card_id
    assert_equal "Retyped", current.name
    assert_equal "CC-99", current.number
    assert_equal 2, member.reload.member_cards.count
  end

  test "update leaves card fields the form does not post" do
    travel_to "2024-06-01"
    org(features: Current.org.features | [ "price_reductions" ])
    member = members(:john)
    card_type = grant_card_reduction!(member, names: { "en" => "Caritas" })
    card = MemberCard.create!(
      member: member,
      price_reduction_card: card_type,
      name: "John",
      number: "QA-0001",
      expires_on: Date.new(2026, 9, 30))
    login(member)

    patch members_account_path, params: {
      member: {
        name: member.name,
        member_cards_attributes: [
          { number: "QA-0006" }
        ]
      }
    }

    assert_redirected_to members_account_path
    card.reload
    assert_equal "QA-0006", card.number
    assert_equal "John", card.name
    assert_equal Date.new(2026, 9, 30), card.expires_on
  end

  test "logout remains allowed for an admin-originated session" do
    session = login_as_admin_originated(members(:john))

    delete members_logout_path

    assert_redirected_to members_login_path
    assert session.reload.revoked?
  end

  private

  def grant_card_reduction!(member, names:)
    card_type = PriceReductionCard.create!(
      names: names,
      require_name: true,
      require_number: true,
      require_expires_on: false)
    reduction = PriceReduction.create!(
      names: names,
      percentage: 30,
      price_reduction_card: card_type)
    MembershipPriceReduction.create!(
      membership: member.current_or_future_membership,
      price_reduction: reduction,
      percentage: 30,
      amount: 10)
    card_type
  end
end
