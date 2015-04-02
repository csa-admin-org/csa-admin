require 'rails_helper'

describe ComingHalfdayWorkEmailSender do
  describe '.send' do
    context 'with no halfday_works coming' do
      it 'does not send email' do
        expect { described_class.send }
          .not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context 'with multiple halfday_works' do
      let!(:halfday_work) { create(:halfday_work, date: 3.days.from_now) }
      before do
        create(:halfday_work, date: 2.days.from_now)
        create(:halfday_work, date: 3.days.ago)
      end

      it 'sends one welcome email' do
        expect { described_class.send }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end
  end
end

