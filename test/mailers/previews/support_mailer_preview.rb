# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/support_mailer
class SupportMailerPreview < ActionMailer::Preview
  def ticket_email
    admin = Admin.first || Admin.new(email: "admin@example.com", name: "Admin")
    ticket = Support::Ticket.new(
      priority: :high,
      subject: "Sample Support Ticket",
      content: "This is a sample content for the support ticket.",
      admin: admin,
      context: "Member 42")

    SupportMailer.with(ticket: ticket).ticket_email
  end
end
