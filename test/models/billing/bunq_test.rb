# frozen_string_literal: true

require "test_helper"

class Billing::BunqTest < ActiveSupport::TestCase
  def setup
    @private_key = OpenSSL::PKey::RSA.new(2048)
    @base_credentials = {
      private_key: @private_key.to_pem,
      installation_token: "test_installation_token",
      api_key: "test_api_key",
      user_id: 12345,
      monetary_account_id: 67890
    }
  end

  # ============================================================================
  # Initialization tests
  # ============================================================================

  test "initializes with credentials" do
    client = Billing::Bunq.new(@base_credentials)
    assert_kind_of Billing::Bunq, client
  end

  # ============================================================================
  # sepa_direct_debit_upload tests
  # ============================================================================

  test "sepa_direct_debit_upload raises NotImplementedError" do
    client = Billing::Bunq.new(@base_credentials)

    assert_raises(NotImplementedError) do
      client.sepa_direct_debit_upload("document")
    end
  end

  # ============================================================================
  # parse_date tests
  # ============================================================================

  test "parse_date handles bunq datetime format" do
    client = Billing::Bunq.new(@base_credentials)
    date = client.send(:parse_date, "2025-03-05 16:12:11.918100")
    assert_equal Date.new(2025, 3, 5), date
  end

  test "parse_date returns nil for nil input" do
    client = Billing::Bunq.new(@base_credentials)
    assert_nil client.send(:parse_date, nil)
  end

  test "parse_date returns nil for invalid date" do
    client = Billing::Bunq.new(@base_credentials)
    assert_nil client.send(:parse_date, "not a date")
  end

  # ============================================================================
  # sign_request tests
  # ============================================================================

  test "sign_request produces base64-encoded SHA256 signature" do
    client = Billing::Bunq.new(@base_credentials)

    body = '{"test": "data"}'
    signature = client.send(:sign_request, body)

    # Verify it's valid base64
    decoded = Base64.strict_decode64(signature)
    assert decoded.present?

    # Verify the signature is valid
    public_key = @private_key.public_key
    assert public_key.verify(OpenSSL::Digest.new("SHA256"), decoded, body)
  end

  # ============================================================================
  # payments_data tests (with HTTP stubbing)
  # ============================================================================

  test "payments_data returns empty array when no payments exist" do
    dutch_org # bunq is a Dutch bank, uses SCOR references
    stub_session_server
    stub_bunq_payments([])

    client = Billing::Bunq.new(@base_credentials)
    result = client.payments_data

    assert_empty result
  end

  test "payments_data ignores outgoing payments (negative amounts)" do
    dutch_org # bunq is a Dutch bank, uses SCOR references
    stub_session_server
    payments = [
      bunq_payment(id: 1, amount: "-50.00", description: "Outgoing payment")
    ]
    stub_bunq_payments(payments, last_batch: true)

    client = Billing::Bunq.new(@base_credentials)
    result = client.payments_data

    assert_empty result
  end

  test "payments_data extracts valid SCOR reference from description" do
    dutch_org # bunq is a Dutch bank, uses SCOR references
    stub_session_server
    # Generate a valid SCOR reference for member_id: 1, invoice_id: 1
    ref = scor_reference(member_id: 1, invoice_id: 1)

    payments = [
      bunq_payment(id: 123, amount: "100.00", description: ref)
    ]
    stub_bunq_payments(payments, last_batch: true)

    client = Billing::Bunq.new(@base_credentials)
    result = client.payments_data

    assert_equal 1, result.size

    payment_data = result.first
    assert_equal "bunq", payment_data.origin
    assert_equal 1, payment_data.member_id
    assert_equal 1, payment_data.invoice_id
    assert_equal BigDecimal("100.00"), payment_data.amount
    assert_equal 123, payment_data.fingerprint
  end

  test "payments_data handles multiple payments" do
    dutch_org # bunq is a Dutch bank, uses SCOR references
    stub_session_server
    ref1 = scor_reference(member_id: 1, invoice_id: 1)
    ref2 = scor_reference(member_id: 2, invoice_id: 3)

    payments = [
      bunq_payment(id: 101, amount: "50.00", description: ref1),
      bunq_payment(id: 102, amount: "75.00", description: ref2)
    ]
    stub_bunq_payments(payments, last_batch: true)

    client = Billing::Bunq.new(@base_credentials)
    result = client.payments_data

    assert_equal 2, result.size
    assert_equal [ 1, 2 ], result.map(&:member_id).sort
  end

  test "payments_data ignores payments without valid reference" do
    dutch_org # bunq is a Dutch bank, uses SCOR references
    stub_session_server
    payments = [
      bunq_payment(id: 1, amount: "100.00", description: "Random payment note")
    ]
    stub_bunq_payments(payments, last_batch: true)

    client = Billing::Bunq.new(@base_credentials)
    result = client.payments_data

    assert_empty result
  end

  test "payments_data returns empty array on maintenance error" do
    dutch_org # bunq is a Dutch bank, uses SCOR references
    stub_session_server
    stub_request(:get, bunq_payments_url)
      .to_return(status: 503, body: '{"Error": [{"error_description": "Maintenance"}]}')

    client = Billing::Bunq.new(@base_credentials)
    result = client.payments_data

    assert_empty result
  end

  test "payments_data returns empty array on connection timeout" do
    dutch_org # bunq is a Dutch bank, uses SCOR references
    stub_session_server
    stub_request(:get, bunq_payments_url).to_timeout

    client = Billing::Bunq.new(@base_credentials)
    result = client.payments_data

    assert_empty result
  end

  # ============================================================================
  # Session tests
  # ============================================================================

  test "payments_data raises AuthenticationError when session start fails" do
    stub_request(:post, "#{Billing::Bunq::API_URL}/v1/session-server")
      .to_return(
        status: 200,
        body: { Response: [ { Id: { id: 1 } } ] }.to_json
      )

    client = Billing::Bunq.new(@base_credentials)

    assert_raises(Billing::Bunq::AuthenticationError) do
      client.payments_data
    end
  end

  # ============================================================================
  # Error handling tests
  # ============================================================================

  test "raises AuthenticationError on 401 response" do
    stub_session_server
    stub_request(:get, bunq_payments_url)
      .to_return(status: 401, body: '{"Error": [{"error_description": "Invalid token"}]}')

    client = Billing::Bunq.new(@base_credentials)

    assert_raises(Billing::Bunq::AuthenticationError) do
      client.payments_data
    end
  end

  test "raises AuthenticationError on 403 response" do
    stub_session_server
    stub_request(:get, bunq_payments_url)
      .to_return(status: 403, body: '{"Error": [{"error_description": "Forbidden"}]}')

    client = Billing::Bunq.new(@base_credentials)

    assert_raises(Billing::Bunq::AuthenticationError) do
      client.payments_data
    end
  end

  private

  def bunq_payments_url
    "#{Billing::Bunq::API_URL}/v1/user/#{@base_credentials[:user_id]}/monetary-account/#{@base_credentials[:monetary_account_id]}/payment"
  end

  def stub_session_server
    stub_request(:post, "#{Billing::Bunq::API_URL}/v1/session-server")
      .to_return(
        status: 200,
        body: {
          Response: [
            { Id: { id: 1 } },
            { Token: { token: "test_session_token" } },
            { UserCompany: { id: @base_credentials[:user_id] } }
          ]
        }.to_json
      )
  end

  def stub_bunq_payments(payments, last_batch: false)
    response_body = {
      Response: payments.map { |p| { Payment: p } }
    }

    stub_request(:get, bunq_payments_url)
      .to_return(status: 200, body: response_body.to_json)

    # If this is the last batch or empty, we need to handle pagination.
    # When payments exist, bunq will try to paginate with older_id.
    # Stub the pagination request to return empty to stop the loop.
    if payments.any? && last_batch
      last_id = payments.last["id"]
      stub_request(:get, "#{bunq_payments_url}?older_id=#{last_id}")
        .to_return(status: 200, body: { Response: [] }.to_json)
    end
  end

  def bunq_payment(id:, amount:, description:, created: Time.current.strftime("%Y-%m-%d %H:%M:%S.%6N"))
    {
      "id" => id,
      "created" => created,
      "updated" => created,
      "amount" => { "value" => amount, "currency" => "EUR" },
      "description" => description,
      "type" => "BUNQ",
      "sub_type" => "PAYMENT",
      "alias" => {
        "type" => "IBAN",
        "value" => "NL00BUNQ0000000000",
        "name" => "Test Account"
      },
      "counterparty_alias" => {
        "type" => "IBAN",
        "value" => "NL00INGB0000000001",
        "name" => "Sender Name"
      }
    }
  end

  # Generate a SCOR reference (RF...) for the given member and invoice IDs
  def scor_reference(member_id:, invoice_id:)
    invoice = OpenStruct.new(id: invoice_id, member_id: member_id)
    Billing::ScorReference.new(invoice).to_s
  end
end
