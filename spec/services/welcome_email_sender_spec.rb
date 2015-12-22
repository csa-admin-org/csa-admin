require 'rails_helper'

describe WelcomeEmailSender do
  describe '.send' do
    context 'with no members to welcome' do
      it 'does not send email' do
        expect { WelcomeEmailSender.send }
          .not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context 'with multiple members' do
      let!(:member) { create(:member, :active) }
      before do
        create(:member, :active, welcome_email_sent_at: 1.day.ago)
        create(:member, :active, salary_basket: true)
        create(:member, :trial)
      end

      it 'sends one welcome email' do
        expect { WelcomeEmailSender.send }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it 'sets welcome_email_sent_at to welcomed member' do
        expect { WelcomeEmailSender.send }
          .to change { member.reload.welcome_email_sent_at }.from(nil)
      end
    end
  end
end
