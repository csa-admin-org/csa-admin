class AdminMailerPreview < ActionMailer::Preview
  def invitation_email
    admin = Admin.new(
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    AdminMailer.with(
      admin: admin,
      action_url: 'https://admin.example.com',
    ).invitation_email
  end
end
