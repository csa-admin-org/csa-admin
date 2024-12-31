# frozen_string_literal: true

require "test_helper"

class AbilityTest < ActiveSupport::TestCase
  test "superadmin permissions" do
    ability = Ability.new(admins(:master))

    assert ability.can?(:read, Organization)
    assert ability.can?(:update, Current.org)
    assert ability.can?(:manage, Admin)
    assert_not ability.can?(:destroy, admins(:master))
    assert ability.can?(:manage, ActiveAdmin::Comment)
    assert ability.can?(:create, Absence)

    Current.org.update!(features: [])
    ability = Ability.new(admins(:master))

    assert_not ability.can?(:create, Absence)
  end

  test "read only permissions" do
    admin = admins(:external)
    ability = Ability.new(admin)

    assert ability.can?(:read, ActiveAdmin::Page)
    assert ability.can?(:pdf, Invoice)
    assert_not ability.can?(:read, Organization)
    assert_not ability.can?(:manage, Admin)
    assert_not ability.can?(:destroy, admin)
    assert ability.can?(:update, admin)
    assert ability.can?(:read, ActiveAdmin::Comment)
    assert ability.can?(:create, ActiveAdmin::Comment)
    assert_not ability.can?(:manage, active_admin_comments(:super_admin))
    assert ability.can?(:manage, active_admin_comments(:external))
    assert_not ability.can?(:batch_action, Member)
    assert_not ability.can?(:batch_action, Membership)
    assert_not ability.can?(:batch_action, Invoice)
    assert_not ability.can?(:batch_action, Shop::Product)
  end

  test "member write permissions" do
    admin = admins(:external)
    admin.permission.update!(rights: { member: :write })
    ability = Ability.new(admin)

    assert ability.can?(:create, Member)
    assert ability.can?(:update, Member)
    assert ability.can?(:batch_action, Member)
    assert ability.can?(:become, Member)
    assert ability.can?(:validate, Member.new(state: "pending"))
  end

  test "membership write permissions" do
    admin = admins(:external)
    admin.permission.update!(rights: { membership: :write })
    ability = Ability.new(admin)

    assert ability.can?(:create, Membership)
    assert ability.can?(:update, Membership)
    assert ability.can?(:update, Basket)
    assert ability.can?(:batch_action, Membership)
    assert ability.can?(:renew_all, Membership)
    assert ability.can?(:open_renewal_all, Membership)
    assert ability.can?(:open_renewal, Membership)
    assert ability.can?(:mark_renewal_as_pending, Membership)
    assert ability.can?(:future_billing, Membership)
    assert ability.can?(:renew, Membership)
    assert ability.can?(:cancel, Membership)
  end

  test "billing write permissions" do
    admin = admins(:external)
    admin.permission.update!(rights: { billing: :write })
    ability = Ability.new(admin)

    assert ability.can?(:create, Invoice)
    assert ability.can?(:update, Invoice)
    assert ability.can?(:batch_action, Invoice)
    assert ability.can?(:create, Payment)
    assert ability.can?(:update, Payment)
    assert ability.can?(:batch_action, Payment)
    assert ability.can?(:recurring_billing, Member)
    assert ability.can?(:force_share_billing, Member)
    assert ability.can?(:send_email, Invoice)
    assert ability.can?(:cancel, Invoice)
    assert ability.can?(:import, Payment)

    invoice = invoices(:annual_fee)
    assert ability.can?(:send_email, invoice)

    invoice.member.update!(emails: "")
    assert_not ability.can?(:send_email, invoice)

    invoice.member.update!(emails: "", billing_email: "billing@test.com")
    assert ability.can?(:send_email, invoice)
  end

  test "shop write permissions" do
    Current.org.update!(features: [ :shop ])
    admin = admins(:external)
    admin.permission.update!(rights: { shop: :write })
    ability = Ability.new(admin)

    assert ability.can?(:create, Shop::Order)
    assert ability.can?(:update, Shop::Order)
    assert ability.can?(:batch_action, Shop::Order)
    assert ability.can?(:create, Shop::Product)
    assert ability.can?(:update, Shop::Product)
    assert ability.can?(:batch_action, Shop::Product)
    assert ability.can?(:create, Shop::Producer)
    assert ability.can?(:update, Shop::Producer)
    assert ability.can?(:create, Shop::Tag)
    assert ability.can?(:update, Shop::Tag)
    assert ability.can?(:invoice, Shop::Order)
    assert ability.can?(:cancel, Shop::Order)
  end
end
