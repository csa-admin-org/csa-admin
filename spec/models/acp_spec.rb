require 'rails_helper'

describe ACP do
  specify 'validates that activity_price cannot be 0' do
    acp = ACP.new(activity_price: nil)
    expect(acp).not_to have_valid(:activity_price)
  end

  specify 'validates activity_participations_demanded_logic liquid syntax' do
    acp = ACP.new(activity_participations_demanded_logic: <<~LIQUID)
      {% if member.salary_basket %}
    LIQUID

    expect(acp).not_to have_valid(:activity_participations_demanded_logic)
    expect(acp.errors[:activity_participations_demanded_logic])
      .to include("Liquid syntax error: 'if' tag was never closed")
  end

  specify 'validates QR IBAN' do
    acp = ACP.new(qr_iban: 'CH3230114A012B456789z')
    expect(acp).to have_valid(:qr_iban)

    acp = ACP.new(qr_iban: 'CH 33 30767 000K 5510')
    expect(acp).not_to have_valid(:qr_iban)

    acp = ACP.new(qr_iban: '', ccp: 'foo')
    expect(acp).to have_valid(:qr_iban)
  end

  specify 'ensure billing_starts_after_first_delivery is enabled with_trial_baskets' do
    acp = ACP.new(
      trial_basket_count: 3,
      billing_starts_after_first_delivery: false)

    expect(acp).not_to have_valid(:billing_starts_after_first_delivery)
    expect(acp.errors[:billing_starts_after_first_delivery])
      .to include("ne peut pas être désactivé avec des paniers à l'essai")
  end

  describe '#billing_year_divisions=' do
    it 'keeps only allowed divisions' do
      acp = ACP.new(billing_year_divisions: ['', '1', '6', '12'])
      expect(acp.billing_year_divisions).to eq [1, 12]
    end
  end

  describe 'url=' do
    it 'sets host at the same time' do
      acp = ACP.new(url: 'https://www.ragedevert.ch')
      expect(acp.host).to eq 'ragedevert'
    end
  end

  specify 'creates default deliveries cycle' do
    Tenant.reset
    create(:acp, tenant_name: 'test')
    Tenant.switch!('test')

    expect(DeliveriesCycle.count).to eq 1
    expect(DeliveriesCycle.first).to have_attributes(
      names: {
        'de' => 'Alle',
        'fr' => 'Toutes',
        'it' => 'Tutte'
      })
  end
end
