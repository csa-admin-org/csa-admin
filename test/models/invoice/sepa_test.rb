# frozen_string_literal: true

require "test_helper"
require "timeout"

class Invoice::SEPATest < ActiveSupport::TestCase
  test "persisted sepa_mandate on invoice creation" do
    org(
      features: Current.org.features | [ :sepa ],
      country_code: "DE",
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(
      name: "John Doe",
      country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE89370400440532013000",
      umr: "123",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload

    invoice = create_annual_fee_invoice(member: member)

    assert_equal "DE89370400440532013000", invoice.sepa_mandate.iban
    assert_equal "John Doe", invoice.sepa_debtor_name
    assert_equal "123", invoice.sepa_mandate.umr
    assert_equal Date.parse("2024-01-01"), invoice.sepa_mandate.signed_on
    assert invoice.sepa?
  end

  test "persisted sepa_mandate with different billing info" do
    org(
      features: Current.org.features | [ :sepa ],
      country_code: "DE",
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(
      name: "John Doe",
      country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE89370400440532013000",
      umr: "123",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload
    member.update!(
      different_billing_info: true,
      billing_name: "Acme Corp",
      billing_street: "Billing Street 1",
      billing_city: "Billing City",
      billing_zip: "9999")

    invoice = create_annual_fee_invoice(member: member)

    assert_equal "DE89370400440532013000", invoice.sepa_mandate.iban
    assert_equal "Acme Corp", invoice.sepa_debtor_name
    assert_equal "123", invoice.sepa_mandate.umr
    assert invoice.sepa?
  end

  test "keeps sepa debtor name snapshot when member billing name changes later" do
    org(
      features: Current.org.features | [ :sepa ],
      country_code: "DE",
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(
      name: "John Doe",
      country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE89370400440532013000",
      umr: "123",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload

    invoice = create_annual_fee_invoice(member: member)

    member.update!(
      different_billing_info: true,
      billing_name: "Changed Corp",
      billing_street: "Changed Street 1",
      billing_city: "Changed City",
      billing_zip: "1111")

    assert_equal "John Doe", invoice.reload.sepa_debtor_name
  end

  test "falls back to current billing info when sepa debtor snapshot is missing" do
    org(
      features: Current.org.features | [ :sepa ],
      country_code: "DE",
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = create_member(
      name: "John Doe",
      country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE89370400440532013000",
      umr: "123",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload

    invoice = create_annual_fee_invoice(member: member)
    invoice.update_columns(sepa_debtor_name: nil)

    member.update!(
      different_billing_info: true,
      billing_name: "Fallback Corp",
      billing_street: "Fallback Street 1",
      billing_city: "Fallback City",
      billing_zip: "2222")

    assert_equal "Fallback Corp", invoice.reload.sepa_debtor_name
  end

  test "upload_sepa_direct_debit_order does nothing if order_id already present" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)
    invoice.update!(sent_at: 1.day.ago, sepa_direct_debit_order_id: "N001")

    assert_no_changes -> { invoice.reload.sepa_direct_debit_order_uploaded_at } do
      invoice.upload_sepa_direct_debit_order
    end

    assert_equal "N001", invoice.sepa_direct_debit_order_id
    assert_nil invoice.sepa_direct_debit_order_uploaded_at
  end

  test "upload_sepa_direct_debit_order does nothing if not sepa" do
    invoice = create_annual_fee_invoice

    assert_no_changes -> { invoice.reload.sepa_direct_debit_order_uploaded_at } do
      invoice.upload_sepa_direct_debit_order
    end

    assert_nil invoice.sepa_direct_debit_order_id
    assert_nil invoice.sepa_direct_debit_order_uploaded_at
  end

  test "upload_sepa_direct_debit_order does nothing if no bank_connection" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)

    assert_no_changes -> { invoice.reload.sepa_direct_debit_order_uploaded_at } do
      invoice.upload_sepa_direct_debit_order
    end

    assert_nil invoice.sepa_direct_debit_order_id
    assert_nil invoice.sepa_direct_debit_order_uploaded_at
  end

  test "upload_sepa_direct_debit_order does nothing if bank connection cannot upload" do
    BankConnection.delete_all
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      credentials: { account_number: "123", contract_password: "secret" })
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)
    invoice.touch(:sent_at)

    assert Current.org.bank_connection?
    assert_not Current.org.bank_connection_sepa_direct_debit_upload?
    assert_not invoice.sepa_direct_debit_order_uploadable?
    assert_no_changes -> { invoice.reload.sepa_direct_debit_order_uploaded_at } do
      invoice.upload_sepa_direct_debit_order
    end

    assert_nil invoice.sepa_direct_debit_order_id
    assert_nil invoice.sepa_direct_debit_order_uploaded_at
  end

  test "sepa direct debit PAIN XML defaults to owned pain.008.001.08 without bank connection" do
    BankConnection.delete_all
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)

    assert_equal "pain.008.001.08", invoice.sepa_direct_debit_pain_schema
    assert_includes invoice.sepa_direct_debit_pain_xml, "urn:iso:std:iso:20022:tech:xsd:pain.008.001.08"
  end

  test "sepa direct debit PAIN XML defaults to owned pain.008.001.08 without upload-capable bank connection" do
    BankConnection.delete_all
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    connection = BankConnection.new(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: synthetic_ebics_credentials,
      settings: h005_payment_settings)
    connection.save!(validate: false)
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)

    assert_not Current.org.bank_connection_sepa_direct_debit_upload?
    assert_equal "pain.008.001.08", invoice.sepa_direct_debit_pain_schema
    assert_includes invoice.sepa_direct_debit_pain_xml, "urn:iso:std:iso:20022:tech:xsd:pain.008.001.08"
  end

  test "sepa direct debit PAIN XML uses active bank connection schema" do
    BankConnection.delete_all
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    BankConnection.create!(
      provider: "ebics",
      name: "MULTIVIA",
      active: true,
      state: "ready",
      credentials: synthetic_ebics_credentials(host_id: "MULTIVIA"),
      settings: h005_payment_settings.deep_merge(
        "uploads" => {
          "sepa_direct_debit" => {
            "mode" => "btf",
            "schema" => "pain.008.001.08",
            "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(version: nil)
          }
        }),
      capabilities: sepa_direct_debit_upload_capabilities)
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)

    assert_equal "pain.008.001.08", invoice.sepa_direct_debit_pain_schema
    assert_includes invoice.sepa_direct_debit_pain_xml, "urn:iso:std:iso:20022:tech:xsd:pain.008.001.08"
  end

  require "minitest/mock"
  test "upload_sepa_direct_debit_order uploads and updates invoice" do
    BankConnection.delete_all
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    BankConnection.create!(
      provider: "mock",
      active: true,
      state: "ready",
      credentials: { password: "secret" })
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)
    invoice.touch(:sent_at)

    assert_changes -> { invoice.reload.sepa_direct_debit_order_uploaded_at } do
      invoice.upload_sepa_direct_debit_order
    end

    assert_equal "N042", invoice.sepa_direct_debit_order_id
    assert invoice.sepa_direct_debit_order_uploaded_at?
  end

  test "upload persists the PAIN message ID and payload digest before submission" do
    invoice = sepa_uploadable_invoice
    submitted_xml = nil
    test_case = self
    connection = Object.new
    connection.define_singleton_method(:sepa_direct_debit_upload) do |pain_xml|
      submitted_xml = pain_xml
      claimed_invoice = Invoice.find(invoice.id)
      test_case.assert_equal "submitting", claimed_invoice.sepa_direct_debit_submission_state
      test_case.assert_equal pain_xml[/<MsgId>([^<]+)/, 1], claimed_invoice.sepa_direct_debit_pain_message_id
      test_case.assert_equal Digest::SHA256.hexdigest(pain_xml), claimed_invoice.sepa_direct_debit_pain_payload_sha256
      [ "T042", "N042" ]
    end

    Current.org.stub(:bank_connection, connection) do
      assert invoice.upload_sepa_direct_debit_order
    end

    invoice.reload
    assert_equal submitted_xml[/<MsgId>([^<]+)/, 1], invoice.sepa_direct_debit_pain_message_id
    assert_equal "T042", invoice.sepa_direct_debit_transaction_id
    assert_equal "submitted", invoice.sepa_direct_debit_submission_state
  end

  test "upload does not submit an already claimed direct debit order" do
    invoice = sepa_uploadable_invoice
    invoice.update_columns(
      sepa_direct_debit_submission_state: "submitting",
      sepa_direct_debit_submission_attempted_at: Time.current,
      sepa_direct_debit_pain_message_id: "CSAADMIN/alreadyclaimed",
      sepa_direct_debit_pain_payload_sha256: "digest")
    connection = Object.new
    connection.define_singleton_method(:sepa_direct_debit_upload) { raise "must not submit twice" }

    Current.org.stub(:bank_connection, connection) do
      assert_not invoice.reload.upload_sepa_direct_debit_order
    end

    assert_equal "submitting", invoice.reload.sepa_direct_debit_submission_state
  end

  test "upload marks an ambiguous bank failure uncertain and does not retry" do
    invoice = sepa_uploadable_invoice
    calls = 0
    connection = Object.new
    connection.define_singleton_method(:sepa_direct_debit_upload) do |_pain_xml|
      calls += 1
      raise Timeout::Error, "response lost"
    end

    Current.org.stub(:bank_connection, connection) do
      refute invoice.upload_sepa_direct_debit_order
      refute invoice.reload.upload_sepa_direct_debit_order
    end

    invoice.reload
    assert_equal 1, calls
    assert_equal "uncertain", invoice.sepa_direct_debit_submission_state
    assert invoice.sepa_direct_debit_submission_attempted_at?
    assert invoice.sepa_direct_debit_pain_message_id?
    assert invoice.sepa_direct_debit_pain_payload_sha256?
    assert_not invoice.sepa_direct_debit_order_uploadable?
  end

  test "forced upload audits the rejected submission and claims a new PAIN identity before upload" do
    invoice = sepa_uploadable_invoice
    old_uploaded_at = Time.zone.parse("2026-07-03 10:35:26")
    old_attempted_at = Time.zone.parse("2026-07-03 10:35:25")
    invoice.update_columns(
      sepa_direct_debit_submission_state: "submitted",
      sepa_direct_debit_submission_attempted_at: old_attempted_at,
      sepa_direct_debit_transaction_id: "OLD-TRANSACTION",
      sepa_direct_debit_order_id: "N0DD",
      sepa_direct_debit_order_uploaded_at: old_uploaded_at,
      sepa_direct_debit_pain_message_id: "CSAADMIN/rejected-message",
      sepa_direct_debit_pain_payload_sha256: "a" * 64)
    submitted_xml = nil
    test_case = self
    connection = Object.new
    connection.define_singleton_method(:sepa_direct_debit_upload) do |pain_xml|
      submitted_xml = pain_xml
      claimed_invoice = Invoice.find(invoice.id)
      test_case.assert_equal "submitting", claimed_invoice.sepa_direct_debit_submission_state
      test_case.assert_nil claimed_invoice.sepa_direct_debit_transaction_id
      test_case.assert_nil claimed_invoice.sepa_direct_debit_order_id
      test_case.assert_nil claimed_invoice.sepa_direct_debit_order_uploaded_at
      test_case.refute_equal "CSAADMIN/rejected-message", claimed_invoice.sepa_direct_debit_pain_message_id
      test_case.assert_equal pain_xml[/<MsgId>([^<]+)/, 1], claimed_invoice.sepa_direct_debit_pain_message_id
      test_case.assert_equal Digest::SHA256.hexdigest(pain_xml), claimed_invoice.sepa_direct_debit_pain_payload_sha256
      [ "NEW-TRANSACTION", "NEW-ORDER" ]
    end

    assert_difference(-> { invoice.audits.count }, 2) do
      Current.org.stub(:bank_connection, connection) do
        assert invoice.upload_sepa_direct_debit_order(force: true)
      end
    end

    invoice.reload
    forced_audit = invoice.audits.find { |audit|
      audit.audited_changes.dig("sepa_direct_debit_order_id", 0) == "N0DD"
    }
    assert_equal System.instance, forced_audit.actor
    assert_equal [ "N0DD", nil ], forced_audit.audited_changes.fetch("sepa_direct_debit_order_id")
    assert_equal [ "OLD-TRANSACTION", nil ], forced_audit.audited_changes.fetch("sepa_direct_debit_transaction_id")
    assert_equal "CSAADMIN/rejected-message",
      forced_audit.audited_changes.fetch("sepa_direct_debit_pain_message_id").first
    assert_equal submitted_xml[/<MsgId>([^<]+)/, 1], invoice.sepa_direct_debit_pain_message_id
    assert_equal "NEW-TRANSACTION", invoice.sepa_direct_debit_transaction_id
    assert_equal "NEW-ORDER", invoice.sepa_direct_debit_order_id
    assert_equal "submitted", invoice.sepa_direct_debit_submission_state
  end

  test "forced upload rejects invoices without a previously submitted order" do
    invoice = sepa_uploadable_invoice

    error = assert_raises(Invoice::SEPA::SubmissionReconciliationError) do
      invoice.upload_sepa_direct_debit_order(force: true)
    end

    assert_equal "Forced SEPA direct debit resubmission requires a bank-confirmed rejected submitted order", error.message
    assert_empty invoice.audits.select { |audit|
      audit.audited_changes.key?("sepa_direct_debit_order_id")
    }
  end

  test "forced upload rejects partially tracked submitted identities" do
    invoice = sepa_uploadable_invoice
    invoice.update_columns(
      sepa_direct_debit_submission_state: "submitted",
      sepa_direct_debit_order_id: "N0DD",
      sepa_direct_debit_order_uploaded_at: Time.zone.parse("2026-07-03 10:35:26"))

    assert_raises(Invoice::SEPA::SubmissionReconciliationError) do
      invoice.upload_sepa_direct_debit_order(force: true)
    end

    invoice.reload
    assert_equal "submitted", invoice.sepa_direct_debit_submission_state
    assert_equal "N0DD", invoice.sepa_direct_debit_order_id
  end

  test "forced upload generates PAIN from the locked current invoice state" do
    invoice = sepa_uploadable_invoice
    invoice.update_columns(
      sepa_direct_debit_order_id: "N0DD",
      sepa_direct_debit_order_uploaded_at: Time.zone.parse("2026-07-03 10:35:26"))
    Invoice.where(id: invoice.id).update_all(amount: 12.34)
    submitted_xml = nil
    connection = Object.new
    connection.define_singleton_method(:sepa_direct_debit_upload) do |pain_xml|
      submitted_xml = pain_xml
      [ "NEW-TRANSACTION", "NEW-ORDER" ]
    end

    Current.org.stub(:bank_connection, connection) do
      assert invoice.upload_sepa_direct_debit_order(force: true)
    end

    assert_includes submitted_xml, '<InstdAmt Ccy="EUR">12.34</InstdAmt>'
  end

  test "forced upload marks an ambiguous replacement uncertain and cannot be forced again" do
    invoice = sepa_uploadable_invoice
    invoice.update_columns(
      sepa_direct_debit_submission_state: nil,
      sepa_direct_debit_transaction_id: nil,
      sepa_direct_debit_order_id: "N0DD",
      sepa_direct_debit_order_uploaded_at: Time.zone.parse("2026-07-03 10:35:26"),
      sepa_direct_debit_submission_attempted_at: nil,
      sepa_direct_debit_pain_message_id: nil,
      sepa_direct_debit_pain_payload_sha256: nil)
    calls = 0
    connection = Object.new
    connection.define_singleton_method(:sepa_direct_debit_upload) do |_pain_xml|
      calls += 1
      raise Timeout::Error, "response lost"
    end

    Current.org.stub(:bank_connection, connection) do
      assert_not invoice.upload_sepa_direct_debit_order(force: true)
    end

    invoice.reload
    assert_equal 1, calls
    assert_equal "uncertain", invoice.sepa_direct_debit_submission_state
    assert_nil invoice.sepa_direct_debit_order_id
    assert invoice.audits.any? { |audit|
      audit.audited_changes.dig("sepa_direct_debit_order_id", 0) == "N0DD"
    }
    assert_raises(Invoice::SEPA::SubmissionReconciliationError) do
      invoice.upload_sepa_direct_debit_order(force: true)
    end
    assert_equal 1, calls
  end

  test "bank-confirmed non-acceptance unlocks an uncertain upload without changing its PAIN identity" do
    invoice = sepa_uploadable_invoice
    attempted_at = Time.zone.parse("2026-07-10 09:15:00")
    invoice.update_columns(
      sepa_direct_debit_submission_state: "uncertain",
      sepa_direct_debit_submission_attempted_at: attempted_at,
      sepa_direct_debit_pain_message_id: "CSAADMIN/uncertain-attempt",
      sepa_direct_debit_pain_payload_sha256: "a" * 64)

    assert invoice.confirm_sepa_direct_debit_order_not_accepted!

    invoice.reload
    assert_equal "failed", invoice.sepa_direct_debit_submission_state
    assert_equal attempted_at, invoice.sepa_direct_debit_submission_attempted_at
    assert_equal "CSAADMIN/uncertain-attempt", invoice.sepa_direct_debit_pain_message_id
    assert_equal "a" * 64, invoice.sepa_direct_debit_pain_payload_sha256
  end

  test "bank-confirmed non-acceptance rejects an uncertain upload with a bank order ID" do
    invoice = sepa_uploadable_invoice
    invoice.update_columns(
      sepa_direct_debit_submission_state: "uncertain",
      sepa_direct_debit_submission_attempted_at: Time.current,
      sepa_direct_debit_pain_message_id: "CSAADMIN/uncertain-attempt",
      sepa_direct_debit_pain_payload_sha256: "a" * 64,
      sepa_direct_debit_order_id: "N042")

    assert_raises(Invoice::SEPA::SubmissionReconciliationError) do
      invoice.confirm_sepa_direct_debit_order_not_accepted!
    end

    assert_equal "uncertain", invoice.reload.sepa_direct_debit_submission_state
  end

  test "failed retry submits the byte-stable persisted PAIN payload" do
    invoice = sepa_uploadable_invoice
    generated_at = Time.zone.parse("2026-07-10 09:15:00")
    message_id = "CSAADMIN/failed-attempt"
    pain_xml = invoice.sepa_direct_debit_pain_xml(message_id: message_id, generated_at: generated_at)
    invoice.update_columns(
      sepa_direct_debit_submission_state: "failed",
      sepa_direct_debit_submission_attempted_at: generated_at,
      sepa_direct_debit_pain_message_id: message_id,
      sepa_direct_debit_pain_payload_sha256: Digest::SHA256.hexdigest(pain_xml))
    submitted_xml = nil
    connection = Object.new
    connection.define_singleton_method(:sepa_direct_debit_upload) do |xml|
      submitted_xml = xml
      [ "T042", "N042" ]
    end

    travel_to generated_at + 1.day do
      Current.org.stub(:bank_connection, connection) do
        assert invoice.reload.upload_sepa_direct_debit_order
      end
    end

    assert_equal pain_xml, submitted_xml
    assert_equal "submitted", invoice.reload.sepa_direct_debit_submission_state
  end

  test "failed retry refuses payload digest drift before submission" do
    invoice = sepa_uploadable_invoice
    invoice.update_columns(
      sepa_direct_debit_submission_state: "failed",
      sepa_direct_debit_submission_attempted_at: Time.zone.parse("2026-07-10 09:15:00"),
      sepa_direct_debit_pain_message_id: "CSAADMIN/failed-attempt",
      sepa_direct_debit_pain_payload_sha256: Digest::SHA256.hexdigest("different payload"))
    calls = 0
    connection = Object.new
    connection.define_singleton_method(:sepa_direct_debit_upload) do |_xml|
      calls += 1
    end

    Current.org.stub(:bank_connection, connection) do
      refute invoice.reload.upload_sepa_direct_debit_order
    end

    assert_equal 0, calls
    assert_equal "failed", invoice.reload.sepa_direct_debit_submission_state
  end

  test "validates SEPA direct debit submission states" do
    invoice = create_annual_fee_invoice
    invoice.sepa_direct_debit_submission_state = "unknown"

    assert_not_predicate invoice, :valid?
    assert_includes invoice.errors[:sepa_direct_debit_submission_state], "is not included in the list"
  end

  test "upload preserves bank response IDs when the final local save fails" do
    invoice = sepa_uploadable_invoice
    connection = Object.new
    connection.define_singleton_method(:sepa_direct_debit_upload) { |_pain_xml| [ "T042", "N042" ] }

    invoice.stub(:update!, ->(*) { raise ActiveRecord::RecordInvalid.new(invoice) }) do
      Current.org.stub(:bank_connection, connection) do
        refute invoice.upload_sepa_direct_debit_order
      end
    end

    invoice.reload
    assert_equal "T042", invoice.sepa_direct_debit_transaction_id
    assert_equal "N042", invoice.sepa_direct_debit_order_id
    assert_equal "uncertain", invoice.sepa_direct_debit_submission_state
    assert_nil invoice.sepa_direct_debit_order_uploaded_at
  end

  private

  def h005_payment_settings
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
        }
      }
    }
  end

  def sepa_direct_debit_upload_capabilities
    {
      "h005" => {
        "htd_btf_uploads" => [
          {
            "admin_order_type" => "BTU",
            "service" => Billing::EBICS::Btf::Presets
              .sepa_direct_debit_upload(version: nil)
              .except("order_type", "signature_flag")
          }
        ]
      }
    }
  end

  def sepa_uploadable_invoice
    BankConnection.delete_all
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    BankConnection.create!(
      provider: "mock",
      active: true,
      state: "ready",
      credentials: { password: "secret" })
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    create_annual_fee_invoice(member: member).tap { it.touch(:sent_at) }
  end
end
