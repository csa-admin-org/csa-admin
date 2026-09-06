# frozen_string_literal: true

require "faker"

# Resets and repopulates a demo tenant with fresh, realistic data.
#
# Each demo tenant (demo-fr, demo-en, demo-de) is seeded with the
# organization language matching its suffix. This seeder is designed
# to run periodically (e.g., weekly) to clean up data after potential
# customers have explored the demo. It:
#
# 1. Clears all transactional data (members, invoices, etc.)
# 2. Resets organization settings with all features enabled
# 3. Recreates reference data (basket sizes, depots, delivery cycles)
# 4. Populates members with 3 fiscal years of memberships (growth, churn, mix drift)
# 5. Adds basket content, invoices, shop orders, and payments for realism
# 6. On demo-de, seeds a failed then completed Beitragsrunde that sets share prices
#
# Usage:
#   Tenant.switch("demo-fr") { Demo::Seeder.new.seed! }
#
class Demo::Seeder
  include Demo::Seeder::Organization
  include Demo::Seeder::Cleanup
  include Demo::Seeder::Catalog
  include Demo::Seeder::Members
  include Demo::Seeder::BiddingRounds
  include Demo::Seeder::Mail
  include Demo::Seeder::Billing
  include Demo::Seeder::Contents
  include Demo::Seeder::Activities
  include Demo::Seeder::Shop

  ADMIN_INACTIVE_THRESHOLD = 6.months
  EMAIL_DOMAINS = %w[
    mailinator.com yopmail.com guerrillamail.com
    tempmail.net dispostable.com fakeinbox.com
  ].freeze

  TRANSLATIONS = {
    "Weekly" => { "en" => "Weekly", "fr" => "Hebdomadaire", "de" => "Wöchentlich" },
    "Bi-weekly" => { "en" => "Bi-weekly", "fr" => "Bimensuel", "de" => "Zweiwöchentlich" },
    "Small" => { "en" => "Small", "fr" => "Petit", "de" => "Klein" },
    "Medium" => { "en" => "Medium", "fr" => "Moyen", "de" => "Mittel" },
    "Large" => { "en" => "Large", "fr" => "Grand", "de" => "Gross" },
    "Small basket (1-2 people)" => { "en" => "Small basket (1-2 people)", "fr" => "Petit panier (1-2 personnes)", "de" => "Kleiner Korb (1-2 Personen)" },
    "Medium basket (3-4 people)" => { "en" => "Medium basket (3-4 people)", "fr" => "Panier moyen (3-4 personnes)", "de" => "Mittlerer Korb (3-4 Personen)" },
    "Large basket (5+ people)" => { "en" => "Large basket (5+ people)", "fr" => "Grand panier (5+ personnes)", "de" => "Grosser Korb (5+ Personen)" },
    "Farm pickup" => { "en" => "Farm pickup", "fr" => "Retrait à la ferme", "de" => "Abholung am Hof" },
    "Pick up at the farm" => { "en" => "Pick up at the farm", "fr" => "Retrait directement à la ferme", "de" => "Direkte Abholung am Hof" },
    "Market" => { "en" => "Market", "fr" => "Marché", "de" => "Markt" },
    "Market stand" => { "en" => "Market stand", "fr" => "Stand du marché", "de" => "Marktstand" },
    "Home delivery" => { "en" => "Home delivery", "fr" => "Livraison à domicile", "de" => "Hauslieferung" },
    "Bread" => { "en" => "Bread", "fr" => "Pain", "de" => "Brot" },
    "Eggs" => { "en" => "Eggs", "fr" => "Œufs", "de" => "Eier" },
    "Cheese" => { "en" => "Cheese", "fr" => "Fromage", "de" => "Käse" },
    "Weeding" => { "en" => "Weeding", "fr" => "Désherbage", "de" => "Jäten" },
    "Harvest day" => { "en" => "Harvest day", "fr" => "Journée de récolte", "de" => "Erntetag" },
    "Market duty" => { "en" => "Market duty", "fr" => "Tenue du stand", "de" => "Marktdienst" },
    "Farm" => { "en" => "Farm", "fr" => "Ferme", "de" => "Hof" },
    "Farm fields" => { "en" => "Farm fields", "fr" => "Champs de la ferme", "de" => "Hoffelder" },
    "Town Center" => { "en" => "Town Center", "fr" => "Centre-ville", "de" => "Stadtzentrum" },
    "Carrots" => { "en" => "Carrots", "fr" => "Carottes", "de" => "Karotten" },
    "Potatoes" => { "en" => "Potatoes", "fr" => "Pommes de terre", "de" => "Kartoffeln" },
    "Salad" => { "en" => "Salad", "fr" => "Salade", "de" => "Salat" },
    "Tomatoes" => { "en" => "Tomatoes", "fr" => "Tomates", "de" => "Tomaten" },
    "Zucchini" => { "en" => "Zucchini", "fr" => "Courgettes", "de" => "Zucchini" },
    "Onions" => { "en" => "Onions", "fr" => "Oignons", "de" => "Zwiebeln" },
    "Leeks" => { "en" => "Leeks", "fr" => "Poireaux", "de" => "Lauch" },
    "Cabbage" => { "en" => "Cabbage", "fr" => "Chou", "de" => "Kohl" },
    "Spinach" => { "en" => "Spinach", "fr" => "Épinards", "de" => "Spinat" },
    "Beans" => { "en" => "Beans", "fr" => "Haricots", "de" => "Bohnen" },
    "Honey" => { "en" => "Honey", "fr" => "Miel", "de" => "Honig" },
    "Apple Juice" => { "en" => "Apple Juice", "fr" => "Jus de pomme", "de" => "Apfelsaft" },
    "Dried Herbs" => { "en" => "Dried Herbs", "fr" => "Herbes séchées", "de" => "Getrocknete Kräuter" },
    "Jam" => { "en" => "Jam", "fr" => "Confiture", "de" => "Marmelade" },
    "Pickles" => { "en" => "Pickles", "fr" => "Cornichons", "de" => "Essiggurken" },
    "500g jar" => { "en" => "500g jar", "fr" => "Pot de 500g", "de" => "500g Glas" },
    "250g jar" => { "en" => "250g jar", "fr" => "Pot de 250g", "de" => "250g Glas" },
    "1L bottle" => { "en" => "1L bottle", "fr" => "Bouteille 1L", "de" => "1L Flasche" },
    "3L bag-in-box" => { "en" => "3L bag-in-box", "fr" => "Bag-in-box 3L", "de" => "3L Bag-in-Box" },
    "Bundle" => { "en" => "Bundle", "fr" => "Bouquet", "de" => "Bund" },
    "Jar" => { "en" => "Jar", "fr" => "Bocal", "de" => "Glas" },
    "Strawberry" => { "en" => "Strawberry", "fr" => "Fraise", "de" => "Erdbeere" },
    "Apricot" => { "en" => "Apricot", "fr" => "Abricot", "de" => "Aprikose" },
    "Sunny Acres Apiary" => { "en" => "Sunny Acres Apiary", "fr" => "Rucher des Acres Ensoleillées", "de" => "Sonnige Äcker Imkerei" },
    "Valley Orchard" => { "en" => "Valley Orchard", "fr" => "Verger de la Vallée", "de" => "Tal-Obstgarten" },
    "Green Thumb Gardens" => { "en" => "Green Thumb Gardens", "fr" => "Jardins Main Verte", "de" => "Grüner Daumen Gärten" },
    "Solidarity price" => { "en" => "Solidarity price", "fr" => "Prix solidaire", "de" => "Solidaritätspreis" },
    "Solidarity" => { "en" => "Solidarity", "fr" => "Solidarité", "de" => "Solidarität" },
    "News from the farm" => { "en" => "News from the farm", "fr" => "Nouvelles de la ferme", "de" => "Neuigkeiten vom Hof" },
    "newsletter_content" => {
      "en" => "<p>Dear {{ member.name }},</p><br><p>We hope you're enjoying your baskets! The season is going well and we're excited to share some updates with you.</p><p>See you soon at the farm!</p>",
      "fr" => "<p>Chers {{ member.name }},</p><br><p>Nous espérons que vous appréciez vos paniers ! La saison se passe bien et nous sommes ravis de partager quelques nouvelles avec vous.</p><p>À bientôt à la ferme !</p>",
      "de" => "<p>Liebe {{ member.name }},</p><br><p>Wir hoffen, dass Ihnen Ihre Körbe gefallen! Die Saison läuft gut und wir freuen uns, einige Neuigkeiten mit Ihnen zu teilen.</p><p>Bis bald auf dem Hof!</p>"
    },
    "bidding_round_failed_info" => {
      "de" => "<p>Erste Beitragsrunde der Saison. Bitte legt euren Beitrag fest, damit wir den Bedarf des Hofs decken können.</p>"
    },
    "bidding_round_completed_info" => {
      "de" => "<p>Zweite Beitragsrunde, nachdem die erste den Bedarf nicht gedeckt hat. Der festgelegte Beitrag gilt für die laufende Saison.</p>"
    }
  }.freeze

  CREDITOR_INFO = {
    "en" => { name: "Demo Farm", street: "42 Farm Street", zip: "2300", city: "La Chaux-de-Fonds" },
    "fr" => { name: "Ferme Démo", street: "Rue de la Ferme 42", zip: "2300", city: "La Chaux-de-Fonds" },
    "de" => { name: "Demo Bauernhof", street: "Hofstrasse 42", zip: "30159", city: "Hannover" }
  }.freeze

  ACTIVE_MEMBERS_COUNT = 20
  TRIAL_MEMBERS_COUNT = 3
  WAITING_MEMBERS_COUNT = 3
  SUPPORT_MEMBERS_COUNT = 2
  PENDING_MEMBERS_COUNT = 2
  HISTORICAL_YEAR_COUNT = 3
  FOUNDING_MEMBERS_COUNT = 10
  YEAR_MINUS_ONE_JOINERS_COUNT = 5
  CURRENT_YEAR_JOINERS_COUNT = 5
  YEAR_MINUS_TWO_CHURNED_COUNT = 3
  YEAR_MINUS_ONE_CHURNED_COUNT = 3
  EARLY_EXITS_PER_CHURN_YEAR = 2
  ABSENCES_PER_YEAR = 3
  CONTENTS_COVERAGE_BY_OFFSET = { 2 => 0.70, 1 => 0.80, 0 => 0.90 }.freeze
  PRODUCTS = [
    { key: "Carrots", unit: "kg", price: 4.50 },
    { key: "Potatoes", unit: "kg", price: 3.00 },
    { key: "Salad", unit: "pc", price: 2.50 },
    { key: "Tomatoes", unit: "kg", price: 6.00 },
    { key: "Zucchini", unit: "kg", price: 4.00 },
    { key: "Onions", unit: "kg", price: 3.50 },
    { key: "Leeks", unit: "pc", price: 3.00 },
    { key: "Cabbage", unit: "pc", price: 4.00 },
    { key: "Spinach", unit: "kg", price: 8.00 },
    { key: "Beans", unit: "kg", price: 7.00 }
  ].freeze
  SHOP_PRODUCTS = [
    { key: "Honey", variants: [
      { key: "500g jar", price: 15.00 },
      { key: "250g jar", price: 8.50 }
    ] },
    { key: "Apple Juice", variants: [
      { key: "1L bottle", price: 6.00 },
      { key: "3L bag-in-box", price: 15.00 }
    ] },
    { key: "Dried Herbs", variants: [
      { key: "Bundle", price: 5.00 }
    ] },
    { key: "Jam", variants: [
      { key: "Strawberry", price: 7.50 },
      { key: "Apricot", price: 7.50 }
    ] },
    { key: "Pickles", variants: [
      { key: "Jar", price: 8.00 }
    ] }
  ].freeze
  SHOP_PRODUCERS = [
    { key: "Sunny Acres Apiary", website_url: "https://sunny-acres-apiary.example.com" },
    { key: "Valley Orchard", website_url: "https://valley-orchard.example.com" },
    { key: "Green Thumb Gardens", website_url: "https://green-thumb-gardens.example.com" }
  ].freeze

  def initialize
    raise "Demo::Seeder can only run in a demo tenant" unless Tenant.demo?

    @org_language = Tenant.demo_language
    @org_domain = Tenant.admin_host.sub(/\Aadmin\./, "")
    Faker::Config.locale = @org_language
  end

  def seed!
    log "Starting demo reset..."
    reset_organization_settings!
    cleanup_inactive_admins!
    cleanup_custom_permissions!
    clear_transactional_data!
    clear_reference_data!
    reset_primary_key_sequences!

    # Membership#price is written in after_commit, so bidding rounds must
    # run after this block. Same for Active Storage PDF uploads.
    ActiveRecord::Base.transaction do
      seed_reference_data!
      seed_members!
      seed_email_suppressions!
      seed_absences!
      seed_newsletter!
      seed_invoices_and_payments!
      seed_mail_deliveries!
      seed_basket_contents!
      seed_activities!
      seed_shop!
    end
    seed_bidding_rounds!
    seed_bidding_round_mail_deliveries!(@active_members || [])
    ensure_invoice_pdfs_uploaded!
    ensure_sepa_mandate_pdfs_uploaded!
    mark_deliveries_delivered!
    SearchEntry.rebuild!
    log "Demo reset completed successfully"
  end

  private

  def seed_fiscal_years
    @seed_fiscal_years ||= begin
      current = Current.fiscal_year
      (0...Demo::Seeder::HISTORICAL_YEAR_COUNT).map { |index|
        Current.org.fiscal_year_for(current.year - (HISTORICAL_YEAR_COUNT - 1 - index))
      }
    end
  end

  def fy_offset(fiscal_year)
    Current.fiscal_year.year - fiscal_year.year
  end

  def fy_offset_for_year(year)
    Current.fiscal_year.year - year
  end

  def pick_weighted(weights)
    total = weights.values.sum
    cursor = rand * total
    weights.each do |item, weight|
      cursor -= weight
      return item if cursor <= 0
    end
    weights.keys.last
  end

  def members_with_membership_in(fy)
    Member.joins(:memberships).merge(Membership.during_year(fy)).distinct.to_a
  end

  def members_with_basket_on(delivery)
    Member.joins(memberships: :baskets).where(baskets: { delivery_id: delivery.id }).distinct.to_a
  end

  def members_with_demanded_participations_on(date)
    Member.joins(:memberships)
      .where("memberships.started_on <= ? AND memberships.ended_on >= ?", date, date)
      .where("memberships.activity_participations_demanded > 0")
      .distinct.to_a
  end

  def random_date_in_year(fy, latest: Date.current)
    earliest = fy.beginning_of_year
    latest = [ latest, fy.end_of_year, Date.current ].min
    return if earliest > latest

    rand(earliest..latest)
  end

  def translated_text(key)
    Current.org.languages.index_with do |lang|
      TRANSLATIONS.dig(key, lang) || key
    end
  end

  def simple_localized_text(text)
    Current.org.languages.index_with { |_| text }
  end

  def log(message)
    if defined?(Rails::Console)
      puts "[Demo::Seeder] #{message}"
    else
      Rails.logger.info "[Demo::Seeder] #{message}"
    end
  end
end
