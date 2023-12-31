FactoryBot.define do
  factory :acp do
    name { "Rage de Vert" }
    url { "https://www.ragedevert.ch" }
    logo_url { Rails.root.join("spec/fixtures/files/logo.png") }
    email { "info@ragedevert.ch" }
    phone { "077 447 26 16" }
    sequence(:tenant_name) { |n| "acp#{n}" }
    email_default_host { "https://membres.ragedevert.ch" }
    email_default_from { "info@ragedevert.ch" }
    email_signature { "Au plaisir,\nRage de Vert" }
    email_footer { "En cas de questions ou remarques, répondez simplement à cet email.\nAssociation Rage de Vert, Closel-Bourbon 3, 2075 Thielle" }
    trial_basket_count { 4 }
    billing_year_divisions { [ 1, 4 ] }
    annual_fee { 30 }
    activity_price { 60 }
    qr_iban { "CH4431999123000889012" }
    qr_creditor_name { "Association Rage de Vert" }
    qr_creditor_address { "Closel-Bourbon 3" }
    qr_creditor_city { "Thielle" }
    qr_creditor_zip { "2075" }
    invoice_info { "Payable dans les 30 jours, avec nos remerciements." }
    invoice_footer { "<b>Association Rage de Vert</b>, Closel-Bourbon 3, 2075 Thielle /// info@ragedevert.ch, 076 481 13 84" }
    terms_of_service_url { "https://www.ragedevert.ch/s/RageDeVert-Reglement-2015.pdf" }
    features { %w[absence activity basket_content basket_price_extra shop] }
    feature_flags { %w[] }
    basket_price_extras { "0, 1, 2, 3" }
    basket_price_extra_public_title { "Soutien" }
    basket_price_extra_label { <<~LIQUID }
      {% if extra == 0 %}
      Tarif de base
      {% else %}
      + {{ extra | ceil }}.-/panier
      {% endif %}
    LIQUID
  end
end
