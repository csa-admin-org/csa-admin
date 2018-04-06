require 'rails_helper'

describe DistributionMailer do
  describe 'next_delivery' do
    it 'renders the headers' do
      distribution = create(:distribution, emails: 'john@doe.com, bob@dylan.com')
      delivery = create(:delivery)
      mail = DistributionMailer.next_delivery(distribution, delivery)

      expect(mail.subject).to eq "Rage de Vert: Liste livraison du #{I18n.l delivery.date}"
      expect(mail.to).to eq ['john@doe.com', 'bob@dylan.com']
      expect(mail.from).to eq ['info@ragedevert.ch']
    end

    it 'renders the body' do
      distribution = create(:distribution, emails: 'john@doe.com, bob@dylan.com')
      delivery = create(:delivery)
      member1 = create(:member, name: 'Dylan')
      member2 = create(:member, name: 'Zylan')
      membership1 = create(:membership, member: member1, distribution_id: distribution.id)
      membership2 = create(:membership, member: member2, distribution_id: distribution.id)
      mail = DistributionMailer.next_delivery(distribution, delivery)

      expect(mail.body.encoded).to include(member1.name)
      expect(mail.body.encoded).to include(member1.emails)
      expect(mail.body.encoded).to include(member1.phones)
      expect(mail.body.encoded).to include(membership1.baskets.first.basket_size.name)
      expect(mail.body.encoded).to include(member2.name)
      expect(mail.body.encoded).to include(member2.emails)
      expect(mail.body.encoded).to include(member2.phones)
      expect(mail.body.encoded).to include(membership2.baskets.first.basket_size.name)
    end

    it 'renders the body with complements' do
      distribution = create(:distribution, emails: 'john@doe.com, bob@dylan.com')
      delivery = create(:delivery)
      member1 = create(:member, name: 'Dylan')
      member2 = create(:member, name: 'Zylan')
      create(:basket_complement, id: 1, name: 'Oeufs')
      membership1 = create(:membership, member: member1, distribution_id: distribution.id)
      membership2 = create(:membership, member: member2, distribution_id: distribution.id)
      membership2.baskets.where(delivery: delivery).first.update!(
        baskets_basket_complements_attributes: {
          '0' => { basket_complement_id: 1, quantity: 2 },
        })
      mail = DistributionMailer.next_delivery(distribution, delivery)

      expect(mail.body.encoded).to include(member1.name)
      expect(mail.body.encoded).to include(member1.emails)
      expect(mail.body.encoded).to include(member1.phones)
      expect(mail.body.encoded).to include(membership1.baskets.first.basket_size.name)
      expect(mail.body.encoded).to include(member2.name)
      expect(mail.body.encoded).to include(member2.emails)
      expect(mail.body.encoded).to include(member2.phones)
      expect(mail.body.encoded).to include(membership2.baskets.first.basket_size.name)
      expect(mail.body.encoded).to include("<b>2 x Oeufs</b>")
    end
  end
end
