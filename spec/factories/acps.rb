FactoryBot.define do
  factory :acp do
    name { 'Rage de Vert' }
    url { 'https://www.ragedevert.ch' }
    logo_url { Rails.root.join('spec/fixtures/files/logo.png') }
    email { 'info@ragedevert.ch' }
    phone { '077 447 26 16' }
    sequence(:tenant_name) { |n| "acp#{n}" }
    email_default_host { 'https://membres.ragedevert.ch' }
    email_default_from { 'info@ragedevert.ch' }
    email_signature { "Au plaisir,\nRage de Vert" }
    email_footer { "En cas de questions ou remarques, répondez simplement à cet email.\nAssociation Rage de Vert, Closel-Bourbon 3, 2075 Thielle" }
    trial_basket_count { 4 }
    billing_year_divisions { [1, 4] }
    annual_fee { 30 }
    activity_price { 60 }
    ccp { '01-13734-6' }
    isr_identity { '00 11041 90802 41000' }
    isr_payment_for { "Banque Raiffeisen du Vignoble\n2023 Gorgier" }
    isr_in_favor_of { "Association Rage de Vert\nClosel-Bourbon 3\n2075 Thielle" }
    invoice_info { 'Payable dans les 30 jours, avec nos remerciements.' }
    invoice_footer { '<b>Association Rage de Vert</b>, Closel-Bourbon 3, 2075 Thielle /// info@ragedevert.ch, 076 481 13 84' }
    terms_of_service_url { 'https://www.ragedevert.ch/s/RageDeVert-Reglement-2015.pdf' }
    features { %w[absence activity basket_content basket_price_extra shop] }
    feature_flags { %w[] }
  end
end
