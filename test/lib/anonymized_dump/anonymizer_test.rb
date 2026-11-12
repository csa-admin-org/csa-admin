# frozen_string_literal: true

require "test_helper"

class AnonymizedDumpAnonymizerTest < ActiveSupport::TestCase
  SWISS_EN_PLACES = [ %w[8001 Zurich], %w[1201 Geneva], %w[3000 Bern] ].freeze

  test "verifier rejects fixture personal data" do
    error = assert_raises(AnonymizedDump::Error) { AnonymizedDump::Verifier.call! }

    assert_match(/members\.emails/, error.message)
  end

  test "anonymize rewrites personal data and drops sensitive tables" do
    member = members(:john)
    payment = payments(:other_closed)
    price = memberships(:john).price
    amount = payment.amount
    member.update_columns(
      note: "call john@doe.com",
      food_note: "no nuts",
      contact_sharing: true,
      billing_name: "Bill Doe",
      billing_street: "Bill St 1",
      billing_zip: "9999",
      billing_city: "Billtown",
      billing_email: "bill@doe.com")
    deliveries(:monday_1).update_columns(
      note: "Pay CH4431999123000889012 see /rails/active_storage/blobs/redirect/secret")
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO active_storage_blobs
        (key, filename, byte_size, checksum, created_at, service_name)
      VALUES
        ('secret-blob-key', 'invoice.pdf', 4, 'abcd', CURRENT_TIMESTAMP, 'tmp_disk')
    SQL
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO search_entries
        (searchable_type, searchable_id, content_primary, content_secondary, priority, updated_at)
      VALUES
        ('Member', #{member.id}, 'john@doe.com', '', 1, '2024-01-01')
    SQL
    mandate = SEPAMandate.create!(
      member: member,
      iban: "DE21500500009876543210",
      umr: "MANDATE42",
      signed_on: Date.current,
      sepa_mandate_accepted: "1",
      source: "self-service",
      ip: "203.0.113.5",
      user_agent: "SecretAgent")
    bank = BankConnection.create!(
      provider: "mock",
      active: true,
      state: "ready",
      credentials: { password: "secret-password" })
    forgotten = members(:anna)
    forgotten.update_columns(name: "DELETED", emails: nil, street: nil, phones: nil, anonymized_at: Time.current)

    assert_predicate Invoice, :any?
    assert_predicate Session, :any?

    AnonymizedDump::Anonymizer.call
    AnonymizedDump::Verifier.call!

    member.reload
    assert_not_equal "John Doe", member.name
    assert_match(/@mailinator\.com\z/, member.emails)
    assert_no_match(/doe\.com/, member.emails)
    assert_match(/\A\+4179\d{7}\z/, member.phones)
    assert_includes SWISS_EN_PLACES, [ member.zip, member.city ]
    assert_not_equal "Nowhere 42", member.street
    assert_nil member.note
    assert_nil member.food_note
    assert_not member.contact_sharing
    assert member.different_billing_info
    assert_not_equal "Bill Doe", member.billing_name
    assert_match(/@mailinator\.com\z/, member.billing_email)
    assert_includes SWISS_EN_PLACES, [ member.billing_zip, member.billing_city ]
    assert_equal "DELETED", forgotten.reload.name
    assert_nil forgotten.emails

    assert_equal "42 Nowhere", depots(:farm).reload.street
    assert_equal "info@acme.test", organizations(:acme).reload.email
    assert_equal "anon-api-token", organizations(:acme).api_token
    assert AnonymizedDump::IBAN.valid?(organizations(:acme).iban)
    assert_not_equal "CH4431999123000889012", organizations(:acme).iban
    assert_not_equal "info@csa-admin.org", admins(:ultra).reload.email
    assert_match(/@mailinator\.com\z/, admins(:ultra).email)

    mandate.reload
    assert AnonymizedDump::IBAN.valid?(mandate.iban)
    assert_not_equal "DE21500500009876543210", mandate.iban
    assert_equal "DE", mandate.iban[0, 2]
    assert_nil mandate.ip
    assert_nil mandate.user_agent
    assert_match(/\AANON[0-9a-f]{31}\z/, mandate.umr)

    assert_equal 0, Invoice.count
    assert_equal 0, Session.count
    assert_equal 0, MailDelivery.count
    assert_equal 0, ActiveStorage::Blob.count
    assert_equal 0, SearchEntry.count
    payment.reload
    assert_nil payment.invoice_id
    assert_nil payment.fingerprint
    assert_equal amount, payment.amount
    assert_equal price, memberships(:john).reload.price

    note = deliveries(:monday_1).reload.note
    assert_not_includes note, "CH4431999123000889012"
    assert_not_includes note, "/rails/active_storage/"
    assert_includes note, organizations(:acme).iban

    raw = BankConnection.connection.select_value("SELECT credentials FROM bank_connections WHERE id = #{bank.id}")
    assert_not_includes raw, "secret-password"
    assert_empty bank.reload.credentials

    name = member.name
    AnonymizedDump::Anonymizer.call
    assert_equal name, member.reload.name
    AnonymizedDump::Verifier.call!
  end

  test "refuses to anonymize in production" do
    with_rails_env("production") do
      error = assert_raises(AnonymizedDump::Error) { AnonymizedDump::Anonymizer.call }
      assert_match(/production/, error.message)
    end
    assert_equal "john@doe.com", members(:john).reload.emails
  end
end
