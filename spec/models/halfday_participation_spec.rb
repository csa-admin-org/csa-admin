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
      participation = build(:halfday_participation, halfday: halfday.reload, participants_count: 3)
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
      expect(last_email.subject).to match(/Rage de Vert: ½ Journée validée/)
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
      expect(last_email.subject).to match(/Rage de Vert: ½ Journée refusée/)
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

  describe '#destroyable?' do
    it 'always returns true by the default' do
      halfday = create(:halfday, date: 2.days.from_now)
      participation = create(:halfday_participation, halfday: halfday, created_at: 25.hours.ago)
      expect(participation).to be_destroyable
    end

    it 'returns true when a deletion deadline is set and creation is in the last 24h' do
      Current.acp.update!(halfday_participation_deletion_deadline_in_days: 30)
      halfday = create(:halfday, date: 29.days.from_now)
      participation = create(:halfday_participation, halfday: halfday, created_at: 20.hours.ago)

      expect(participation).to be_destroyable
    end

    it 'returns false when a deletion deadline is set and creation has been done more that 24h ago' do
      Current.acp.update!(halfday_participation_deletion_deadline_in_days: 30)
      halfday = create(:halfday, date: 29.days.from_now)
      participation = create(:halfday_participation, halfday: halfday, created_at: 25.hours.ago)

      expect(participation).not_to be_destroyable
    end
  end

  describe '#reminderable?' do
    it 'returns true when halfday is in less than two weeks' do
      halfday = create(:halfday, date: 2.weeks.from_now - 1.hour)
      participation = create(:halfday_participation,
        halfday: halfday,
        created_at: 2.months.ago,
        latest_reminder_sent_at: nil)
      expect(participation).to be_reminderable
    end

    it 'returns false when halfday is in less than two weeks but already reminded' do
      halfday = create(:halfday, date: 2.weeks.from_now - 1.hour)
      participation = create(:halfday_participation,
        halfday: halfday,
        created_at: 2.months.ago,
        latest_reminder_sent_at: Time.current)
      expect(participation).not_to be_reminderable
    end

    it 'returns false when halfday is in more than two weeks' do
      halfday = create(:halfday, date: 15.days.from_now)
      participation = create(:halfday_participation,
        halfday: halfday,
        created_at: 2.months.ago,
        latest_reminder_sent_at: nil)
      expect(participation).not_to be_reminderable
    end

    it 'returns false when participation has been created in less than a month' do
      halfday = create(:halfday, date: 2.weeks.from_now - 1.hour)
      participation = create(:halfday_participation,
        halfday: halfday,
        created_at: 3.weeks.ago,
        latest_reminder_sent_at: nil)
      expect(participation).not_to be_reminderable
    end

    it 'returns true when halfday is in less than three days' do
      halfday = create(:halfday, date: 3.days.from_now - 1.hour)
      participation = create(:halfday_participation,
        halfday: halfday,
        created_at: 2.months.ago,
        latest_reminder_sent_at: 2.weeks.ago)
      expect(participation).to be_reminderable
    end

    it 'returns true when halfday is in less than three days and never reminded' do
      halfday = create(:halfday, date: 3.days.from_now - 1.hour)
      participation = create(:halfday_participation,
        halfday: halfday,
        created_at: 1.day.ago,
        latest_reminder_sent_at: nil)
      expect(participation).to be_reminderable
    end

    it 'returns false when halfday is in less than three days but already reminded' do
      halfday = create(:halfday, date: 3.days.from_now - 1.hour)
      participation = create(:halfday_participation,
        halfday: halfday,
        created_at: 2.months.ago,
        latest_reminder_sent_at: 6.days.ago)
      expect(participation).not_to be_reminderable
    end

    it 'returns false when halfday is in less than three days but already reminded (now)' do
      halfday = create(:halfday, date: 3.days.from_now - 1.hour)
      participation = create(:halfday_participation,
        halfday: halfday,
        created_at: 2.months.ago,
        latest_reminder_sent_at: Time.current)
      expect(participation).not_to be_reminderable
    end

    it 'returns false when halfday has past' do
      halfday = create(:halfday, date: 1.day.ago)
      participation = create(:halfday_participation,
        halfday: halfday,
        created_at: 2.months.ago,
        latest_reminder_sent_at: nil)
      expect(participation).not_to be_reminderable
    end
  end

  it 'updates membership recognized_halfday_works' do
    member = create(:member)
    membership = create(:membership, member: member)

    participation = build(:halfday_participation,
      halfday: create(:halfday, date: 1.day.ago),
      member: member,
      participants_count: 2)

    expect { participation.save! }
      .to change { membership.reload.recognized_halfday_works }.by(2)
    expect { participation.reject!(create(:admin)) }
      .to change { membership.reload.recognized_halfday_works }.by(-2)
  end
end
