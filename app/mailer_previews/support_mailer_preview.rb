# frozen_string_literal: true

class SupportMailerPreview < ActionMailer::Preview
  def ping_email
    SupportMailer.with(message: sample_message).ping_email
  end

  def wrap_email
    SupportMailer.with(message: sample_reply).wrap_email
  end

  private

  def sample_ticket
    admin = Admin.new(email: "admin@example.com", name: "Admin")
    ticket = Support::Ticket.new(
      id: 42,
      token: "deadbeef",
      priority: :high,
      subject: "Sample Support Ticket",
      content: "This is a sample content for the support ticket.",
      admin: admin,
      context: "https://admin.example.test/members/42")
    ticket.define_singleton_method(:wrap_emails_for) { |_| [ admin.email ] }
    ticket.define_singleton_method(:participants) { [ admin ] }
    ticket.define_singleton_method(:ping_address) { "support@csa-admin.org" }
    ticket
  end

  def sample_message
    Support::Message.new(
      id: 1,
      ticket: sample_ticket,
      author: "admin",
      admin: sample_ticket.admin,
      admin_name: sample_ticket.admin.name,
      body: "This is a sample content for the support ticket.",
      created_at: Time.current)
  end

  def sample_reply
    opening = sample_message
    Support::Message.new(
      id: 2,
      ticket: opening.ticket,
      author: "support",
      body: "Here is the answer.",
      created_at: Time.current).tap do |reply|
      reply.define_singleton_method(:previous) { opening }
    end
  end
end
