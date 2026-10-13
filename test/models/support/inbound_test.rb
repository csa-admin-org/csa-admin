# frozen_string_literal: true

require "test_helper"

class Support::InboundTest < ActiveSupport::TestCase
  CASES = YAML.safe_load(
    Rails.root.join("test/fixtures/files/support/inbound.yml").read).freeze

  def ingest(payload)
    perform_enqueued_jobs only: Support::InboundJob do
      Support::InboundJob.perform_later(payload)
    end
  end

  def operator_env
    {
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org"
    }
  end

  def load_case(name)
    spec = CASES.fetch(name.to_s).deep_dup
    email = admins(:external).email
    walk = ->(value) {
      case value
      when String then value.gsub("ADMIN_EMAIL", email)
      when Array then value.map { |item| walk.call(item) }
      when Hash then value.transform_values { |item| walk.call(item) }
      else value
      end
    }
    walk.call(spec)
  end

  def payload_for(spec, extras = {})
    {
      "From" => extras["From"],
      "To" => extras["To"],
      "Subject" => extras["Subject"] || "Re: Help",
      "TextBody" => spec["text"],
      "HtmlBody" => spec["html"],
      "Attachments" => spec["attachments"],
      "MessageID" => extras["MessageID"],
      "Headers" => extras["Headers"]
    }.compact
  end

  def parsed(name)
    Support::Inbound.parse(payload_for(load_case(name)))
  end

  CASES.each_key do |name|
    test "parses #{name}" do
      spec = load_case(name)
      inbound = parsed(name)
      expected = spec.fetch("expect")

      if expected["original_from"]
        assert_equal expected["original_from"], inbound.original_from
      else
        assert_nil inbound.original_from
      end
      if expected["reply"].present?
        assert_includes inbound.reply.body.to_s, expected["reply"]
        assert_not_includes inbound.reply.body.to_s, expected["original"].to_s
      else
        assert inbound.reply.blank?
      end
      if expected["original"].present?
        assert_includes inbound.original.body.to_s, expected["original"]
        assert_not_includes inbound.original.body.to_s, expected["reply"].to_s
        assert inbound.hops.any?
      else
        assert inbound.original.blank?
        assert_empty inbound.hops
      end
    end

    test "converts #{name}" do
      spec = load_case(name)
      expected = spec.fetch("expect")
      error = ErrorRecorder.new

      with_env(operator_env) do
        with_rails_error(error) do
          ingest(payload_for(spec,
            "To" => "ticket-acme@support.csa-admin.org",
            "From" => "support+high@csa-admin.org",
            "Subject" => "Re: Help",
            "MessageID" => "convert-#{name}",
            "Headers" => [ {
              "Name" => "Message-ID",
              "Value" => "<convert-#{name}@mail>"
            } ]))
        end
      end

      if spec["attachments"].present? && expected["reply"].blank? && expected["original"].blank?
        ticket = Support::Ticket.order(:id).last
        assert ticket
        assert_equal 1, ticket.messages.count
        assert_equal 1, ticket.messages.first.attachments.count
        return
      end

      ticket = Support::Ticket.order(:id).last
      assert ticket
      if expected["original"].present?
        original, reply = ticket.messages.order(:id).to_a
        assert_equal "admin", original.author
        assert_includes original.body, expected["original"]
        assert_not_includes original.body, expected["reply"]
        if expected["original_from"] == admins(:external).email
          assert_equal admins(:external), ticket.admin
          assert_equal admins(:external), original.admin
        end
        if expected["reply"].present?
          assert_equal "support", reply.author
          assert_includes reply.body, expected["reply"]
          assert_not_includes reply.body, expected["original"]
        end
      elsif expected["reply"].present?
        assert_equal 1, ticket.messages.count
        assert_includes ticket.messages.first.body, expected["reply"]
      end
    end

    test "replies #{name}" do
      spec = load_case(name)
      expected = spec.fetch("expect")
      ticket = Support::Ticket.create!(
        priority: :normal,
        subject: "Help",
        content: "Opening",
        admin: admins(:external))

      with_env(operator_env) do
        ingest(payload_for(spec,
          "To" => ticket.inbound_email,
          "From" => admins(:external).email,
          "MessageID" => "reply-#{name}",
          "Headers" => [ {
            "Name" => "Message-ID",
            "Value" => "<reply-#{name}@mail>"
          } ]))
      end

      message = ticket.messages.order(:id).last
      if spec["attachments"].present? && expected["reply"].blank?
        assert_equal 1, message.attachments.count
        return
      end

      assert_equal "admin", message.author
      assert_equal admins(:external), message.admin
      if expected["reply"].present?
        assert_includes message.body, expected["reply"]
        assert_not_includes message.body, expected["original"].to_s
      end
    end
  end

  test "drops a convert from a sender that is not allowlisted" do
    error = ErrorRecorder.new

    with_env(operator_env) do
      with_rails_error(error) do
        assert_no_difference "Support::Ticket.count" do
          ingest(
            "To" => "ticket-acme@support.csa-admin.org",
            "From" => "stranger@example.com",
            "TextBody" => "Please help\n\nOn Monday, Jane Doe <#{admins(:external).email}> wrote:\nHello",
            "MessageID" => "convert-denied")
        end
      end
    end

    reported, context, = error.reports.first
    assert_equal "Support inbound convert rejected sender", reported.message
    assert_equal "stranger@example.com", context[:from]
  end

  test "reports when a convert original is not an admin" do
    error = ErrorRecorder.new

    with_env(operator_env) do
      with_rails_error(error) do
        assert_difference "Support::Ticket.count" => 1 do
          ingest(
            "To" => "ticket-acme@support.csa-admin.org",
            "From" => "support+high@csa-admin.org",
            "TextBody" => "Here is the answer\n\nOn Monday, Pat Lee <pat@example.com> wrote:\nHello",
            "Headers" => [ {
              "Name" => "Message-ID",
              "Value" => "<convert-unmatched@mail>"
            } ])
        end
      end
    end

    ticket = Support::Ticket.order(:id).last
    original = ticket.messages.order(:id).first
    assert_nil ticket.admin
    assert_nil original.admin
    reported, context, = error.reports.first
    assert_equal "Support inbound convert unmatched admin", reported.message
    assert_equal "pat@example.com", context[:original_from]
  end

  test "sets admin on the ticket and opening message when the original matches" do
    with_env(operator_env) do
      ingest(
        "To" => "ticket-acme@support.csa-admin.org",
        "From" => "support+high@csa-admin.org",
        "TextBody" => "Here is the answer\n\nOn Monday, Jane Doe <#{admins(:external).email}> wrote:\nHello",
        "Headers" => [ {
          "Name" => "Message-ID",
          "Value" => "<convert-admin-both@mail>"
        } ])
    end

    ticket = Support::Ticket.order(:id).last
    original = ticket.messages.order(:id).first
    assert_equal admins(:external), ticket.admin
    assert_equal admins(:external), original.admin
  end

  test "skips a blank convert" do
    assert_no_difference "Support::Ticket.count" do
      ingest(
        "To" => "ticket-acme@support.csa-admin.org",
        "From" => ENV["ULTRA_ADMIN_EMAIL"],
        "TextBody" => "",
        "HtmlBody" => "",
        "MessageID" => "blank-convert")
    end
  end

  test "does not persist an empty cited hop" do
    html = <<~HTML
      <html><body>
        <div>Here is the answer</div>
        <blockquote type="cite">On Monday, Jane Doe &lt;#{admins(:external).email}&gt; wrote:<br><br></blockquote>
        <blockquote type="cite"><div>Hello from the member</div></blockquote>
      </body></html>
    HTML

    with_env(operator_env) do
      assert_difference "Support::Ticket.count" => 1, "Support::Message.count" => 2 do
        ingest(
          "To" => "ticket-acme@support.csa-admin.org",
          "From" => "support+high@csa-admin.org",
          "TextBody" => "",
          "HtmlBody" => html,
          "Headers" => [ {
            "Name" => "Message-ID",
            "Value" => "<convert-empty-hop@mail>"
          } ])
      end
    end

    ticket = Support::Ticket.order(:id).last
    original, reply = ticket.messages.order(:id).to_a
    assert_includes original.body, "Hello from the member"
    assert_not_includes original.body, "On Monday"
    assert_includes reply.body, "Here is the answer"
  end

  test "drops a reply from a sender that is not allowlisted" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    assert_no_difference "Support::Message.count" do
      ingest(
        "To" => ticket.inbound_email,
        "From" => "stranger@example.com",
        "TextBody" => "Hello",
        "MessageID" => "reply-denied")
    end
  end
end
