require 'rails_helper'

describe HalfdayParticipation do
  let(:member) { create(:member) }
  let(:admin) { create(:admin) }

  def last_email
    ActionMailer::Base.deliveries.last
  end

  describe 'validations' do
    it 'validates halfday participants limit' do
      halfday = create(:halfday, participants_limit: 3)
      create(:halfday_participation, halfday: halfday, participants_count: 1)
      participation = build(:halfday_participation, halfday: halfday, participants_count: 3)
      expect(participation).not_to have_valid(:participants_count)
    end
  end

  describe '#validate!' do
    it 'sets states column and deliver validated email' do
      halfday = create(:halfday, date: 3.days.ago)
      participation = create(:halfday_participation, halfday: halfday)
      expect { participation.validate!(admin) }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(participation.state).to eq 'validated'
      expect(participation.validated_at).to be_present
      expect(participation.validator).to eq admin
      expect(last_email.subject).to match /Rage de Vert: ½ Journée validée/
    end
  end

  describe '#reject!' do
    it 'sets states column and deliver rejected email' do
      halfday = create(:halfday, date: 3.days.ago)
      participation = create(:halfday_participation, halfday: halfday)
      expect { participation.reject!(admin) }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(participation.state).to eq 'rejected'
      expect(participation.rejected_at).to be_present
      expect(participation.validator).to eq admin
      expect(last_email.subject).to match /Rage de Vert: ½ Journée refusée/
    end
  end

  describe '#carpooling=' do
    let(:participation) { build(:halfday_participation, member: member) }

    it 'does not set carpooling_phone if carpooling = 0' do
      participation.carpooling = '0'
      participation.save
      expect(participation.carpooling_phone).to be_nil
    end

    it 'sets first member phones if carpooling_phone is blank' do
      participation.carpooling = '1'
      participation.carpooling_phone = ''
      participation.save
      expect(participation.carpooling_phone).to eq member.phones_array.first
    end

    it 'uses carpooling_phone when present' do
      participation.carpooling = '1'
      participation.carpooling_phone = '077 123 41 12'
      participation.save
      expect(participation.carpooling_phone).to eq '+41771234112'
    end
  end
end
