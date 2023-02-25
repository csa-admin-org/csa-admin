require 'rails_helper'

describe 'Email Suppressions' do
  let(:member) { create(:member) }

  before do
    Capybara.app_host = 'http://membres.ragedevert.test'
    login(member)
  end

  specify 'subscribe back to newsletters' do
    suppression = EmailSuppression.suppress!(member.emails_array.first,
      stream_id: 'broadcast',
      origin: 'Customer',
      reason: 'ManualSuppression')

    visit '/account'

    expect {
      click_on "Je souhaite à nouveau m'inscrire aux newsletters"
    }.to change { suppression.reload.unsuppressed_at }.from(nil)

    expect(current_path).to eq('/account')
    expect(page).to have_selector('.flash',
      text: "Merci de vous être à nouveau inscrit à nos newsletters!")
    expect(page).not_to have_content("Je souhaite à nouveau m'inscrire aux newsletters")
  end

  specify 'do not allow Mailchimp origin re-subscription' do
    suppression = EmailSuppression.suppress!(member.emails_array.first,
      stream_id: 'broadcast',
      origin: 'Mailchimp',
      reason: 'Forgotten')
    expect(Current.acp.mailchimp?).to be true

    visit '/account'

    expect(page).not_to have_content("Je souhaite à nouveau m'inscrire aux newsletters")
  end
end
