require 'rails_helper'

describe 'Newsletter subscriptions' do
  before { Capybara.app_host = 'http://membres.ragedevert.test' }

  describe 'unsubscribe' do
    specify 'with valid token' do
      email = 'johnnyjames@gmail.com'
      member = create(:member, emails: email)
      token = Newsletter::Audience.encrypt_email(email)

      expect {
        visit "/newsletters/unsubscribe/#{token}"
      }.to change { EmailSuppression.active.broadcast.count }.by(1)
      expect(EmailSuppression.active.broadcast.last).to have_attributes(
        email: email,
        reason: 'ManualSuppression',
        origin: 'Customer')

      expect(page)
        .to have_content 'Votre email (joh...mes@gma...com) a été supprimé de la liste de diffusion.'
      expect(postmark_client.calls).to eq [
        [:create_suppressions, 'broadcast', email]
      ]
    end

    specify 'with valid token (short email)' do
      email = 'joe@do.com'
      member = create(:member, emails: email)
      token = Newsletter::Audience.encrypt_email(email)

      expect {
        visit "/newsletters/unsubscribe/#{token}"
      }.to change { EmailSuppression.active.broadcast.count }.by(1)

      expect(page).to have_content '(j...e@do...om)'
    end

    specify 'with invalid token' do
      expect {
        visit "/newsletters/unsubscribe/foo"
      }.not_to change { EmailSuppression.active.broadcast.count }

      expect(page.status_code).to eq 404
      expect(page).to have_content "Ce lien a expiré ou n'est pas valide."
    end

    specify 'with email no more link to a member' do
      email = 'unknown@gmail.com'
      token = Newsletter::Audience.encrypt_email(email)

      expect {
        visit "/newsletters/unsubscribe/#{token}"
      }.not_to change { EmailSuppression.active.broadcast.count }

      expect(page.status_code).to eq 404
      expect(page).to have_content "Ce lien a expiré ou n'est pas valide."
    end
  end

  specify 're-subscribe' do
    email = 'johnnyjames@gmail.com'
    member = create(:member, emails: email)
    token = Newsletter::Audience.encrypt_email(email)

    expect {
      visit "/newsletters/unsubscribe/#{token}"
    }.to change { EmailSuppression.active.broadcast.count }.by(1)

    suppression = EmailSuppression.active.broadcast.last
    expect(suppression).to have_attributes(
      email: email,
      reason: 'ManualSuppression',
      origin: 'Customer',
      unsuppressed_at: nil)

    expect {
      click_button "Je m'inscris à nouveau."
    }.to change { EmailSuppression.active.broadcast.count }.by(-1)
    expect(suppression.reload.unsuppressed_at).to be_present

    expect(page)
      .to have_content 'Votre email (joh...mes@gma...com) est à nouveau inscrit à la liste de diffusion.'

    expect(postmark_client.calls).to eq [
      [:create_suppressions, 'broadcast', email],
      [:delete_suppressions, 'broadcast', email]
    ]
  end
end
