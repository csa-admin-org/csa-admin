# frozen_string_literal: true

require "ostruct"

class AdminMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def delivery_list_email
    admin = Admin.new(
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    delivery = Delivery.new(id: 1, date: Date.new(2020, 11, 10))
    AdminMailer.with(
      admin: admin,
      delivery: delivery
    ).delivery_list_email
  end

  def invitation_email
    admin = Admin.new(
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    AdminMailer.with(
      admin: admin,
      action_url: "https://admin.example.com",
    ).invitation_email
  end

  def ebics_setup_submitted_email
    AdminMailer.with(
      admin: ebics_admin,
      connection: ebics_connection
    ).ebics_setup_submitted_email
  end

  def ebics_setup_finalized_email
    AdminMailer.with(
      admin: ebics_admin,
      connection: ebics_connection(
        state: "ready",
        active: true,
        health_status: "healthy",
        onboarding_state: "finalized")
    ).ebics_setup_finalized_email
  end

  def invoice_overpaid_email
    admin = Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    member =  Member.new(
      id: 2,
      name: "Martha")
    invoice = Invoice.new(id: 42)
    AdminMailer.with(
      admin: admin,
      member: member,
      invoice: invoice
    ).invoice_overpaid_email
  end

  def invoice_third_overdue_notice_email
    admin = Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    member =  Member.new(
      id: 2,
      name: "Martha")
    invoice = Invoice.new(id: 42, member: member)
    AdminMailer.with(
      admin: admin,
      invoice: invoice
    ).invoice_third_overdue_notice_email
  end

  def payment_reversal_email
    admin = Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    member = Member.new(name: "Martha")
    invoice = Invoice.new(id: 42)
    payment = Payment.new(id: 42, invoice: invoice)
    AdminMailer.with(
      admin: admin,
      member: member,
      payment: payment
    ).payment_reversal_email
  end

  def new_absence_email
    admin = Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    member = Member.new(name: "Martha")
    absence = Absence.new(
      id: 1,
      started_on: Date.new(2020, 11, 10),
      ended_on: Date.new(2020, 11, 20),
      note: "Une Super Remarque!")
    AdminMailer.with(
      admin: admin,
      member: member,
      absence: absence
    ).new_absence_email
  end

  def new_activity_participation_email
    admin = Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    member = Member.new(name: "Martha")
    act_preset = ActivityPreset.all.sample(random: random)
    act = Activity.last(10).sample(random: random)
    activity = OpenStruct.new(
      title: act_preset&.title || "Aide aux champs",
      date: Date.current,
      period: act&.period || "8:00-12:00",
      description: nil,
      place: act_preset&.title || "Neuchâtel",
      place_url: act_preset&.place_url || "https://google.map/foo")
    activity_participation = OpenStruct.new(
      activity_id: 1,
      member_id: 1,
      member: member,
      activity: activity,
      participants_count: 2,
      carpooling_phone: "077 231 123 43",
      carpooling_city: "La Chaux-de-Fonds",
      note: "Une Super Remarque!")
    AdminMailer.with(
      admin: admin,
      activity_participation: activity_participation
    ).new_activity_participation_email
  end

  def new_email_suppression_email
    admin = Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    email_suppression = OpenStruct.new(
      reason: "HardBounce",
      email: "john@doe.com",
      owners: [
        Member.new(
          id: 2,
          name: "Martha")
      ])
    AdminMailer.with(
      admin: admin,
      email_suppression: email_suppression
    ).new_email_suppression_email
  end

  def new_registration_email
    admin = Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    member =  Member.new(
      id: 2,
      name: "Martha")
    AdminMailer.with(
      admin: admin,
      member: member
    ).new_registration_email
  end

  def new_shop_order_email
    admin = Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    member = Member.new(
      id: 2,
      name: "Martha")
    delivery = Delivery.new(
      id: 3,
      date: Date.new(2024, 6, 10))
    order = Shop::Order.new(
      id: 42,
      member: member,
      delivery: delivery,
      amount: 32.50)
    AdminMailer.with(
      admin: admin,
      shop_order: order
    ).new_shop_order_email
  end

  def membership_trial_cancelation_email
    admin = Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    member = Member.new(
      id: 2,
      name: "Martha")
    membership = OpenStruct.new(
      id: 1,
      ended_on: Date.new(2024, 4, 15),
      renewal_note: "The delivery schedule doesn't work for our family.",
      renewal_annual_fee: 30)
    AdminMailer.with(
      admin: admin,
      member: member,
      membership: membership
    ).membership_trial_cancelation_email
  end

  def memberships_renewal_pending_email
    admin = Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
    membership_1 = Membership.new(id: 1)
    membership_2 = Membership.new(id: 2)
    membership_3 = Membership.new(id: 3)
    AdminMailer.with(
      admin: admin,
      pending_memberships: [ membership_1, membership_2 ],
      opened_memberships: [ membership_3 ],
      pending_action_url: "https://admin.example.com/memberships",
      opened_action_url: "https://admin.example.com/memberships",
      action_url: "https://admin.example.com/memberships"
    ).memberships_renewal_pending_email
  end

  private

  def ebics_admin
    Admin.new(
      id: 1,
      name: "John",
      language: I18n.locale,
      email: "admin@csa-admin.org")
  end

  def ebics_connection(state: "waiting_for_bank", active: false, health_status: "unknown", onboarding_state: "waiting_for_bank")
    BankConnection.new(
      id: 42,
      provider: "ebics",
      name: "EBICS Bank",
      active: active,
      state: state,
      health_status: health_status,
      credentials: ebics_credentials,
      settings: { "protocol" => "H005" },
      status_details: ebics_status_details(onboarding_state))
  end

  def ebics_credentials
    {
      "url" => "https://ebics.example.test",
      "host_id" => "PREVIEW_HOSTID",
      "client_id" => "PREVIEW_CLIENTID",
      "participant_id" => "PREVIEW_PARTICIPANTID",
      "secret" => "PREVIEW_SECRET",
      "keys" => "PREVIEW PRIVATE KEY MATERIAL"
    }
  end

  def ebics_status_details(state)
    {
      "onboarding" => {
        "state" => state,
        "target_bits" => 4096,
        "initiated_at" => 1.hour.ago.iso8601,
        "initiated_by_admin_id" => 1,
        "initiated_by_admin_email" => "admin@csa-admin.org",
        "ini_submitted_at" => 58.minutes.ago.iso8601,
        "hia_submitted_at" => 57.minutes.ago.iso8601,
        "finalized_at" => (5.minutes.ago.iso8601 if state == "finalized")
      }.compact
    }
  end
end
