# frozen_string_literal: true

require "test_helper"

class Members::SEPAMandatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  def sepa_member
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member
  end

  test "new requires authentication" do
    get new_members_sepa_mandate_path

    assert_redirected_to members_login_path
  end

  test "new renders the mandate page for SEPA-capable org" do
    member = sepa_member
    login(member)

    get new_members_sepa_mandate_path

    assert_response :success
  end

  test "new redirects when org is not SEPA-capable" do
    org(country_code: "CH", sepa_creditor_identifier: nil)

    member = members(:john)
    login(member)

    get new_members_sepa_mandate_path

    assert_redirected_to members_billing_path
  end

  test "create persists IBAN and writes a mandate" do
    member = sepa_member
    login(member)

    assert_difference("SEPAMandate.count", 1) do
      post members_sepa_mandate_path, params: {
        sepa_mandate: {
          iban: "DE21500500009876543210",
          sepa_mandate_accepted: "1"
        }
      }
    end

    assert_redirected_to members_billing_path

    member.reload
    assert_equal "DE21500500009876543210", member.iban
    assert_equal member.id.to_s, member.current_sepa_mandate.umr
    assert_equal Date.current, member.current_sepa_mandate.signed_on
    assert member.sepa?

    mandate = member.sepa_mandates.recent_first.first
    assert_equal "DE21500500009876543210", mandate.iban
    assert_equal "self-service", mandate.source
    assert_equal "127.0.0.1", mandate.ip
  end

  test "create rejects when consent checkbox not ticked" do
    member = sepa_member
    login(member)

    assert_no_difference("SEPAMandate.count") do
      post members_sepa_mandate_path, params: {
        sepa_mandate: {
          iban: "DE21500500009876543210",
          sepa_mandate_accepted: "0"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_nil member.reload.iban
  end

  test "create rejects when consent param is missing" do
    member = sepa_member
    login(member)

    assert_no_difference("SEPAMandate.count") do
      post members_sepa_mandate_path, params: {
        sepa_mandate: {
          iban: "DE21500500009876543210"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_nil member.reload.iban
  end

  test "create rejects invalid IBAN" do
    member = sepa_member
    login(member)

    assert_no_difference("SEPAMandate.count") do
      post members_sepa_mandate_path, params: {
        sepa_mandate: {
          iban: "DE00000000000000000000",
          sepa_mandate_accepted: "1"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_nil member.reload.iban
  end

  test "create keeps UMR stable on IBAN change" do
    travel_to "2024-01-01"
    member = sepa_member
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "custom-umr",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.reload

    login(member)

    travel_to "2024-03-15"
    assert_difference("SEPAMandate.count", 1) do
      post members_sepa_mandate_path, params: {
        sepa_mandate: {
          iban: "DE89370400440532013000",
          sepa_mandate_accepted: "1"
        }
      }
    end

    member.reload
    assert_equal "DE89370400440532013000", member.iban
    assert_equal "custom-umr", member.current_sepa_mandate.umr
    assert_equal Date.parse("2024-03-15"), member.current_sepa_mandate.signed_on
  end

  test "create re-enables disabled member" do
    member = sepa_member
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "custom-umr",
      signed_on: Date.parse("2024-01-01"),
      source: "admin")
    member.disable_sepa!
    member.reload

    assert_not member.sepa?

    login(member)

    assert_difference("SEPAMandate.count", 1) do
      post members_sepa_mandate_path, params: {
        sepa_mandate: {
          iban: "DE89370400440532013000",
          sepa_mandate_accepted: "1"
        }
      }
    end

    member.reload
    assert member.sepa?
    assert_nil member.sepa_disabled_at
    assert_equal "DE89370400440532013000", member.iban
    assert_equal "custom-umr", member.current_sepa_mandate.umr
  end

  test "create enqueues confirmation email when template active" do
    template = mail_templates(:sepa_mandate_confirmation)
    template.update!(active: true)

    member = sepa_member
    login(member)
    enable_sepa_mandate_pdf

    assert_difference [ "SEPAMandateMailer.deliveries.size" ], 1 do
      perform_enqueued_jobs do
        post members_sepa_mandate_path, params: {
          sepa_mandate: {
            iban: "DE21500500009876543210",
            sepa_mandate_accepted: "1"
          }
        }
      end
    end
  ensure
    skip_sepa_mandate_pdf
  end

  test "create redirects when org is not SEPA-capable" do
    org(country_code: "CH", sepa_creditor_identifier: nil)

    member = members(:john)
    login(member)

    post members_sepa_mandate_path, params: {
      sepa_mandate: {
        iban: "DE21500500009876543210",
        sepa_mandate_accepted: "1"
      }
    }

    assert_redirected_to members_billing_path
  end
end
