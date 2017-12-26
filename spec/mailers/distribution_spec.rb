require 'rails_helper'

describe DistributionMailer do
  describe 'next_delivery' do
    it 'renders the headers' do
      distribution = create(:distribution, emails: 'john@doe.com, bob@dylan.com')
      delivery = create(:delivery, date: '21/3/2017')
      mail = DistributionMailer.next_delivery(distribution, delivery)

      expect(mail.subject).to eq 'Rage de Vert: Liste livraison du 21 mars 2017'
      expect(mail.to).to eq ['john@doe.com', 'bob@dylan.com']
      expect(mail.from).to eq ['info@ragedevert.ch']
    end

    it 'renders the body' do
      distribution = create(:distribution)
      delivery = create(:delivery)
      member1 = create(:member, last_name: 'Dylan')
      member2 = create(:member, last_name: 'Zylan')
      membership1 = create(:membership, member: member1, distribution_id: distribution.id)
      membership2 = create(:membership, member: member2, distribution_id: distribution.id)
      mail = DistributionMailer.next_delivery(distribution, delivery)

      expect(mail.body.encoded).to include(member1.name)
      expect(mail.body.encoded).to include(member1.emails)
      expect(mail.body.encoded).to include(member1.phones)
      expect(mail.body.encoded).to include(membership1.basket_size.name)
      expect(mail.body.encoded).to include(member2.name)
      expect(mail.body.encoded).to include(member2.emails)
      expect(mail.body.encoded).to include(member2.phones)
      expect(mail.body.encoded).to include(membership2.basket_size.name)
    end
  end
end
