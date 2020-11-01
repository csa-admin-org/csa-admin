require 'rails_helper'

describe AdminMailer do
  specify '#invitation_email' do
    admin = Admin.new(
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    mail = AdminMailer.with(
      admin: admin,
      action_url: 'https://admin.example.com',
    ).invitation_email

    expect(mail.subject).to eq("Invitation à l'admin de Rage de Vert")
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include('admin@acp-admin.ch')
    expect(mail.body).to include("Accèder à l'admin de Rage de Vert")
    expect(mail.body).to include('https://admin.example.com')
    expect(mail.from).to eq(['info@ragedevert.ch'])
  end
end
