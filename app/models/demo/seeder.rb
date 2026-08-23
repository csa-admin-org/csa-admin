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
#
# Usage:
#   Tenant.switch("demo-fr") { Demo::Seeder.new.seed! }
#
class Demo::Seeder
  ADMIN_INACTIVE_THRESHOLD = 6.months
  # Disposable email domains that are MX-valid but obviously for demo/testing
  EMAIL_DOMAINS = %w[
    mailinator.com yopmail.com guerrillamail.com
    tempmail.net dispostable.com fakeinbox.com
  ].freeze

  # Translations for demo data (en, fr, de)
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
    # Basket content products
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
    # Shop products
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
    # Shop producers
    "Sunny Acres Apiary" => { "en" => "Sunny Acres Apiary", "fr" => "Rucher des Acres Ensoleillées", "de" => "Sonnige Äcker Imkerei" },
    "Valley Orchard" => { "en" => "Valley Orchard", "fr" => "Verger de la Vallée", "de" => "Tal-Obstgarten" },
    "Green Thumb Gardens" => { "en" => "Green Thumb Gardens", "fr" => "Jardins Main Verte", "de" => "Grüner Daumen Gärten" },
    # Basket price extra
    "Solidarity price" => { "en" => "Solidarity price", "fr" => "Prix solidaire", "de" => "Solidaritätspreis" },
    "Solidarity" => { "en" => "Solidarity", "fr" => "Solidarité", "de" => "Solidarität" },
    # Newsletter
    "News from the farm" => { "en" => "News from the farm", "fr" => "Nouvelles de la ferme", "de" => "Neuigkeiten vom Hof" },
    "newsletter_content" => {
      "en" => "<p>Dear {{ member.name }},</p><br><p>We hope you're enjoying your baskets! The season is going well and we're excited to share some updates with you.</p><p>See you soon at the farm!</p>",
      "fr" => "<p>Chers {{ member.name }},</p><br><p>Nous espérons que vous appréciez vos paniers ! La saison se passe bien et nous sommes ravis de partager quelques nouvelles avec vous.</p><p>À bientôt à la ferme !</p>",
      "de" => "<p>Liebe {{ member.name }},</p><br><p>Wir hoffen, dass Ihnen Ihre Körbe gefallen! Die Saison läuft gut und wir freuen uns, einige Neuigkeiten mit Ihnen zu teilen.</p><p>Bis bald auf dem Hof!</p>"
    }
  }.freeze

  # Creditor info per language (static fake addresses)
  # Note: demo-de uses a German address, demo-fr and demo-en use Swiss addresses
  CREDITOR_INFO = {
    "en" => { name: "Demo Farm", street: "42 Farm Street", zip: "2300", city: "La Chaux-de-Fonds" },
    "fr" => { name: "Ferme Démo", street: "Rue de la Ferme 42", zip: "2300", city: "La Chaux-de-Fonds" },
    "de" => { name: "Demo Bauernhof", street: "Hofstrasse 42", zip: "30159", city: "Hannover" }
  }.freeze

  # Member counts for seeding
  ACTIVE_MEMBERS_COUNT = 20
  TRIAL_MEMBERS_COUNT = 3
  WAITING_MEMBERS_COUNT = 3
  SUPPORT_MEMBERS_COUNT = 2
  PENDING_MEMBERS_COUNT = 2

  # Current-year actives split across a 3-year cohort (must sum to ACTIVE_MEMBERS_COUNT)
  HISTORICAL_YEAR_COUNT = 3
  FOUNDING_MEMBERS_COUNT = 10
  YEAR_MINUS_ONE_JOINERS_COUNT = 5
  CURRENT_YEAR_JOINERS_COUNT = 5
  YEAR_MINUS_TWO_CHURNED_COUNT = 3
  YEAR_MINUS_ONE_CHURNED_COUNT = 3
  EARLY_EXITS_PER_CHURN_YEAR = 2
  ABSENCES_PER_YEAR = 3
  CONTENTS_COVERAGE_BY_OFFSET = { 2 => 0.70, 1 => 0.80, 0 => 0.90 }.freeze

  # Basket content products with typical units and prices
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

  # Shop products with variants
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

    # Clearing must happen outside transaction for PRAGMA to work
    reset_organization_settings!
    cleanup_inactive_admins!
    cleanup_custom_permissions!
    clear_transactional_data!
    clear_reference_data!
    reset_primary_key_sequences!

    # Seeding can be in a transaction for consistency
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
    mark_deliveries_delivered!
    SearchEntry.rebuild!

    log "Demo reset completed successfully"
  end

  private

  def reset_organization_settings!
    log "Resetting organization settings..."

    org = Organization.instance

    # Features to exclude (require additional configuration)
    excluded_features = %i[
      annual_fee
      bidding_round
      local_currency
      member_information
      new_member_fee
      shares
      vat
    ]
    excluded_features << :sepa unless germany?
    enabled_features = (Organization::FEATURES - excluded_features).map(&:to_s)

    org.update!(
      name: "CSA Admin Demo",

      # Enable most features for demo (excluding those requiring extra config)
      features: enabled_features,

      # Single language matching the demo tenant
      languages: [ @org_language ],
      basket_i18n_scopes: {
        "fr" => "basket",
        "de" => "share",
        "it" => "basket",
        "nl" => "package",
        "en" => "basket"
      },
      phone: nil,
      email: "info@csa-admin.org",
      email_default_from: "info@#{@org_domain}",

      # Creditor info (for invoices)
      creditor_name: creditor_info[:name],
      creditor_street: creditor_info[:street],
      creditor_zip: creditor_info[:zip],
      creditor_city: creditor_info[:city],
      country_code: germany? ? "DE" : "CH",
      currency_code: germany? ? "EUR" : "CHF",

      # ============================================
      # Billing settings (billing tab)
      # ============================================
      recurring_billing_wday: 1,
      billing_year_divisions: [ 1, 4, 12 ],
      trial_baskets_count: 2,
      send_closed_invoice: false,
      billing_starts_after_first_delivery: false,
      billing_ends_on_last_delivery_fy_month: false,
      sepa_creditor_identifier: germany? ? "DE98ZZZ09999999999" : nil,
      bank_reference: nil,

      # Invoice settings
      iban: germany? ? "DE87200500001234567890" : "CH5530024123456789012",
      # invoice_infos: {},
      invoice_sepa_info: germany? ? "Der Betrag wird per SEPA-Lastschrift eingezogen." : nil,
      # invoice_footers: {},
      invoice_document_names: {},
      invoice_membership_summary_only: false,

      # VAT settings
      vat_number: nil,
      vat_membership_rate: nil,
      vat_activity_rate: nil,
      vat_shop_rate: nil,

      # Annual fee
      annual_fee: nil,
      annual_fee_member_form: false,
      annual_fee_support_member_only: false,

      # Shares
      share_price: nil,
      shares_number: nil,

      # ============================================
      # Registration settings (registration tab)
      # ============================================
      member_form_extra_text_only: false,
      member_form_complement_quantities: false,
      basket_sizes_member_order_mode: "price_desc",
      basket_complements_member_order_mode: "deliveries_count_desc",
      depots_member_order_mode: "price_asc",
      delivery_cycles_member_order_mode: "deliveries_count_desc",
      allow_alternative_depots: false,
      member_profession_form_mode: "visible",
      member_come_from_form_mode: "visible",
      charter_urls: {},
      statutes_urls: {},
      privacy_policy_url: {},
      terms_of_service_url: "https://csa-admin.org",

      # ============================================
      # Member information settings (member_information section)
      # ============================================
      member_information_titles: {},
      social_network_urls: "",

      # ============================================
      # Membership settings (membership tab)
      # ============================================
      membership_depot_update_allowed: false,
      membership_complements_update_allowed: false,
      basket_update_limit_in_days: 0,

      # ============================================
      # Membership renewal settings
      # ============================================
      open_renewal_reminder_sent_after_in_days: nil,
      membership_renewed_attributes: %w[
        baskets_annual_price_change
        basket_complements_annual_price_change
        activity_participations
        absences_included_annually
      ],
      membership_renewal_depot_update: true,

      # ============================================
      # Delivery PDF settings
      # ============================================
      delivery_pdf_footers: {},
      delivery_pdf_member_info: "none",
      delivery_pdf_member_name_format: "none",
      basket_content_delivery_pdf_visible: false,

      # ============================================
      # Mailer settings
      # ============================================
      # email_signatures: default_email_signature,
      # email_footers: default_email_footer,

      # ============================================
      # Absence feature settings
      # ============================================
      absences_billed: true,
      absence_notice_period_in_days: 7,
      absence_extra_text_only: false,
      basket_shifts_annually: 0,
      basket_shift_deadline_in_weeks: 4,
      absences_included_mode: "provisional_absence",
      absences_included_reminder_weeks_before: 4,
      absences_included_logic: Organization::AbsenceFeature::ABSENCES_INCLUDED_LOGIC_DEFAULT,

      # ============================================
      # Activity feature settings
      # ============================================
      activity_i18n_scope: "halfday_work",
      activity_price: 60,
      activity_participations_form_min: nil,
      activity_participations_form_max: nil,
      activity_participations_form_step: 1,
      activity_participations_form_details: {},
      activity_participations_demanded_logic: Organization::ActivityFeature::ACTIVITY_PARTICIPATIONS_DEMANDED_LOGIC_DEFAULT,
      activity_availability_limit_in_days: 3,
      activity_participation_deletion_deadline_in_days: nil,
      activity_phone: nil,

      # ============================================
      # Basket price extra feature settings
      # ============================================
      basket_price_extras: "0, 2, 4, 6",
      basket_price_extra_titles: translated_text("Solidarity price"),
      basket_price_extra_public_titles: translated_text("Solidarity"),
      basket_price_extra_texts: {},
      basket_price_extra_label_details: {},
      basket_price_extra_dynamic_pricing: nil,

      # ============================================
      # Shop feature settings
      # ============================================
      shop_admin_only: false,
      shop_order_maximum_weight_in_kg: nil,
      shop_order_minimal_amount: nil,
      shop_member_percentages: "",
      shop_delivery_open_delay_in_days: nil,
      shop_delivery_open_last_day_end_time: nil,
      shop_order_automatic_invoicing_delay_in_days: nil,
      shop_invoice_infos: {},
      shop_delivery_pdf_footers: {},
      shop_terms_of_sale_urls: {},
    )

    org.send(:set_defaults)
    org.send(:set_basket_price_extra_defaults)
    org.save!

    # Clear rich text fields (ActionText)
    clear_organization_rich_texts!(org)
  end

  def creditor_info
    CREDITOR_INFO.fetch(@org_language)
  end

  def germany?
    @org_language == "de"
  end

  def clear_organization_rich_texts!(org)
    # Rich text fields that need to be cleared
    rich_text_fields = %i[
      open_renewal_text
      membership_update_text
      member_information_text
      member_form_subtitle
      member_form_extra_text
      member_form_complements_text
      member_form_activity_participations_text
      absence_extra_text
      shop_text
    ]

    Organization.languages.each do |locale|
      rich_text_fields.each do |field|
        rich_text_name = "#{field}_#{locale}"
        rich_text = org.send(rich_text_name)
        rich_text.body = nil if rich_text.present?
      end
    end

    org.save!
  end

  def cleanup_inactive_admins!
    log "Cleaning up inactive admins..."

    # Keep ultra admin and recently active admins
    ultra_email = ENV["ULTRA_ADMIN_EMAIL"]

    Admin.find_each do |admin|
      next if admin.email == ultra_email

      # Check if admin has any recent session activity
      last_activity = admin.sessions.used.maximum(:last_used_at)

      if last_activity && last_activity < ADMIN_INACTIVE_THRESHOLD.ago
        log "Removing inactive admin: #{admin.email}"
        admin.destroy
      end
    end
  end

  def cleanup_custom_permissions!
    log "Cleaning up custom permissions..."

    superadmin = Permission.superadmin

    # Reassign any admins with custom permissions to superadmin
    Admin.where.not(permission_id: Permission::SUPERADMIN_ID).update_all(permission_id: superadmin.id)

    # Delete all non-superadmin permissions
    Permission.where.not(id: Permission::SUPERADMIN_ID).delete_all
  end

  def clear_transactional_data!
    log "Clearing transactional data..."

    # Disable foreign key checks for SQLite to avoid constraint issues
    ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF")

    begin
      # ActiveStorage (purge to also delete files from storage service, but keep org logo and its variants)
      org_logo_blob_id = Organization.instance.logo.blob&.id
      org_logo_variant_record_ids = org_logo_blob_id ? ActiveStorage::VariantRecord.where(blob_id: org_logo_blob_id).pluck(:id) : []

      ActiveStorage::Attachment
        .where.not(record_type: "Organization", name: "logo")
        .where.not(record_type: "ActiveStorage::VariantRecord", record_id: org_logo_variant_record_ids)
        .find_each(&:purge)

      # Ensure logo variant is present
      Current.org.logo.variant(resize_to_limit: [ 330, 330 ]).processed.download

      # Shop orders
      Shop::OrderItem.delete_all
      Shop::Order.delete_all

      # Newsletters
      MailDelivery::Email.delete_all
      MailDelivery.delete_all
      ActionText::RichText.where(record_type: "Newsletter::Block").delete_all
      Newsletter::Block.delete_all
      Newsletter.delete_all

      # Activities
      ActivityParticipation.delete_all
      Activity.delete_all

      # Absences (BasketShift depends on Absence)
      BasketShift.delete_all
      Absence.delete_all

      # Billing
      Payment.delete_all
      InvoiceItem.delete_all
      Invoice.delete_all

      # Baskets
      BasketsBasketComplement.delete_all
      Basket.delete_all

      # Memberships
      MembershipsBasketComplement.delete_all
      MembersBasketComplement.delete_all
      Membership.delete_all

      # Sessions (keep admin sessions)
      Session.where.not(member_id: nil).delete_all

      # Members
      Member.delete_all

      # Misc
      EmailSuppression.delete_all
      Audit.delete_all
    ensure
      # Re-enable foreign key checks
      ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
    end
  end

  def clear_reference_data!
    log "Clearing reference data..."

    # Disable foreign key checks for SQLite to avoid constraint issues
    ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF")

    begin
      ActiveRecord::Base.connection.execute("DELETE FROM basket_contents_depots")
      BasketContent.delete_all
      BasketContent::Product.delete_all
      ForcedDelivery.delete_all
      Delivery.delete_all
      DeliveryCycle::Period.delete_all
      ActiveRecord::Base.connection.execute("DELETE FROM basket_complements_deliveries")
      ActiveRecord::Base.connection.execute("DELETE FROM delivery_cycles_depots")
      BasketComplement.delete_all
      Depot.delete_all
      BasketSize.delete_all
      DeliveryCycle.delete_all
      ActivityPreset.delete_all

      # Shop reference data
      ActiveRecord::Base.connection.execute("DELETE FROM shop_products_tags")
      ActiveRecord::Base.connection.execute("DELETE FROM shop_products_special_deliveries")
      Shop::ProductVariant.delete_all
      Shop::Product.delete_all
      Shop::Producer.delete_all
      Shop::Tag.delete_all
      Shop::SpecialDelivery.delete_all

      # Reset default configuration models (cleared after transactional data)
      MailTemplate.delete_all
      Newsletter::Template.delete_all
    ensure
      # Re-enable foreign key checks
      ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
    end
  end

  def reset_primary_key_sequences!
    log "Resetting primary key sequences..."

    # In SQLite, auto-increment sequences are stored in sqlite_sequence table.
    # Deleting entries resets sequences so new records start from 1.
    ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence")
  end

  def seed_reference_data!
    log "Seeding reference data..."

    create_delivery_cycles!
    create_basket_sizes!
    create_depots!
    create_basket_complements!
    create_deliveries!
    create_basket_content_products!
    create_activity_presets!
    create_shop_producers!
    create_shop_products!
    create_default_configurations!
  end

  def create_default_configurations!
    log "Creating default configurations..."

    MailTemplate.create_all!
    Newsletter::Template.create_defaults!
  end

  def create_delivery_cycles!
    @weekly_cycle = DeliveryCycle.create!(
      names: translated_text("Weekly"),
      wdays: [ 2 ], # Tuesdays
      absences_included_annually: 2,
      periods_attributes: [ { from_fy_month: 4, to_fy_month: 11 } ]
    )

    @biweekly_cycle = DeliveryCycle.create!(
      names: translated_text("Bi-weekly"),
      wdays: [ 2 ], # Tuesdays
      absences_included_annually: 1,
      periods_attributes: [ { from_fy_month: 4, to_fy_month: 11, results: :even } ]
    )
  end

  def create_basket_sizes!
    @small = BasketSize.create!(
      names: translated_text("Small"),
      public_names: translated_text("Small basket (1-2 people)"),
      price: 22,
      activity_participations_demanded_annually: 2
    )

    @medium = BasketSize.create!(
      names: translated_text("Medium"),
      public_names: translated_text("Medium basket (3-4 people)"),
      price: 33,
      activity_participations_demanded_annually: 3
    )

    @large = BasketSize.create!(
      names: translated_text("Large"),
      public_names: translated_text("Large basket (5+ people)"),
      price: 44,
      activity_participations_demanded_annually: 4
    )
  end

  def create_depots!
    @farm_depot = Depot.create!(
      names: translated_text("Farm pickup"),
      public_names: translated_text("Pick up at the farm"),
      price: 0,
      language: Current.org.default_locale,
      street: "Chemin de la Ferme 1",
      zip: "1000",
      city: "Lausanne",
      delivery_cycles: [ @weekly_cycle, @biweekly_cycle ]
    )

    @market_depot = Depot.create!(
      names: translated_text("Market"),
      public_names: translated_text("Market stand"),
      price: 2,
      language: Current.org.default_locale,
      street: "Place du Marché",
      zip: "1003",
      city: "Lausanne",
      delivery_cycles: [ @weekly_cycle, @biweekly_cycle ]
    )

    @home_depot = Depot.create!(
      names: translated_text("Home delivery"),
      price: 8,
      language: Current.org.default_locale,
      delivery_sheets_mode: "home_delivery",
      delivery_cycles: [ @weekly_cycle ]
    )

    @all_depots = [ @farm_depot, @market_depot, @home_depot ]
  end

  def create_basket_complements!
    @bread = BasketComplement.create!(
      names: translated_text("Bread"),
      price: 6,
      delivery_ids: []
    )

    @eggs = BasketComplement.create!(
      names: translated_text("Eggs"),
      price: 5,
      delivery_ids: []
    )

    @cheese = BasketComplement.create!(
      names: translated_text("Cheese"),
      price: 12,
      delivery_ids: []
    )

    @all_complements = [ @bread, @eggs, @cheese ]
  end

  def create_deliveries!
    @deliveries_by_year = {}
    seed_fiscal_years.each do |fy|
      @deliveries_by_year[fy.year] = create_deliveries_for_year!(fy)
    end
    @current_year_deliveries = @deliveries_by_year[Current.fiscal_year.year]
  end

  def create_deliveries_for_year!(fiscal_year)
    start_date = fiscal_year.beginning_of_year
    end_date = fiscal_year.end_of_year

    # Generate Tuesday dates within the period (April-November typically)
    date = start_date
    date += (2 - date.wday) % 7 # Move to next Tuesday

    deliveries = []
    while date <= end_date
      # Only create deliveries April through November (typical growing season)
      if date.month.between?(4, 11)
        delivery = Delivery.new(date: date, shop_open: false)
        # Skip date validation for past deliveries (demo data includes full year)
        delivery.save!(validate: date >= Date.current)
        deliveries << delivery
      end
      date += 1.week
    end

    # Attach basket complements to some deliveries
    deliveries.each_with_index do |delivery, i|
      complement_ids = []
      complement_ids << @bread.id if i.even?
      complement_ids << @eggs.id if (i % 3).zero?
      if complement_ids.any?
        delivery.basket_complement_ids = complement_ids
        # Skip validation for past deliveries
        delivery.save!(validate: delivery.date >= Date.current)
      end
    end

    deliveries
  end

  def create_basket_content_products!
    @products = PRODUCTS.map do |product_data|
      BasketContent::Product.create!(
        names: translated_text(product_data[:key]),
        unit: product_data[:unit],
        default_price: product_data[:price]
      )
    end
  end

  def create_activity_presets!
    ActivityPreset.create!(
      titles: translated_text("Weeding"),
      places: translated_text("Farm"),
      place_urls: simple_localized_text("https://maps.google.com")
    )

    ActivityPreset.create!(
      titles: translated_text("Harvest day"),
      places: translated_text("Farm fields"),
      place_urls: simple_localized_text("https://maps.google.com")
    )

    ActivityPreset.create!(
      titles: translated_text("Market duty"),
      places: translated_text("Town Center"),
      place_urls: simple_localized_text("https://maps.google.com")
    )
  end

  def create_shop_producers!
    return unless Current.org.feature?("shop")

    @shop_producers = SHOP_PRODUCERS.map do |producer_data|
      Shop::Producer.create!(
        name: TRANSLATIONS.dig(producer_data[:key], @org_language),
        website_url: producer_data[:website_url]
      )
    end
  end

  def create_shop_products!
    return unless Current.org.feature?("shop")

    @shop_products = SHOP_PRODUCTS.each_with_index.map do |product_data, index|
      producer = @shop_producers[index % @shop_producers.size]
      product = Shop::Product.new(
        names: translated_text(product_data[:key]),
        available: true,
        producer: producer
      )

      product_data[:variants].each do |variant_data|
        product.variants.build(
          names: translated_text(variant_data[:key]),
          price: variant_data[:price],
          available: true,
          stock: rand(40..80)
        )
      end

      product.save!
      product
    end

    open_shop_deliveries!
  end

  def open_shop_deliveries!
    deliveries_to_open = Delivery.coming.limit(8)
    if deliveries_to_open.empty?
      deliveries_to_open = Delivery.order(date: :desc).limit(8)
    end
    deliveries_to_open.each do |delivery|
      delivery.shop_open = true
      delivery.save!(validate: delivery.date >= Date.current)
    end

    seed_fiscal_years.each do |fy|
      past = Delivery.during_year(fy).where(date: ...Date.current).order(:date).to_a
      next if past.size < 3

      [ past.size / 3, (past.size * 2) / 3 ].uniq.each do |index|
        delivery = past[index]
        delivery.shop_open = true
        delivery.save!(validate: false)
      end
    end
  end

  def seed_members!
    log "Seeding members..."

    @founding_members = create_members!(FOUNDING_MEMBERS_COUNT, state: "active", trial_baskets_count: 0)
    @year_minus_one_joiners = create_members!(YEAR_MINUS_ONE_JOINERS_COUNT, state: "active", trial_baskets_count: 0)
    @current_year_joiners = create_members!(CURRENT_YEAR_JOINERS_COUNT, state: "active", trial_baskets_count: 0)
    @year_minus_two_churned = create_members!(YEAR_MINUS_TWO_CHURNED_COUNT, state: "inactive", trial_baskets_count: 0)
    @year_minus_one_churned = create_members!(YEAR_MINUS_ONE_CHURNED_COUNT, state: "inactive", trial_baskets_count: 0)

    @active_members = @founding_members + @year_minus_one_joiners + @current_year_joiners
    TRIAL_MEMBERS_COUNT.times { @active_members << create_trial_member! }
    WAITING_MEMBERS_COUNT.times { create_waiting_member! }
    SUPPORT_MEMBERS_COUNT.times { create_support_member! }
    PENDING_MEMBERS_COUNT.times { create_pending_member! }

    seed_membership_history!
  end

  def create_members!(count, **attrs)
    Array.new(count) { create_member!(**attrs) }
  end

  def create_trial_member!
    member = create_member!(state: "active")
    create_membership!(member, late_start: true)
    member
  end

  def create_waiting_member!
    create_member!(
      state: "waiting",
      waiting_started_at: rand(30..90).days.ago,
      waiting_basket_size: [ @small, @medium, @large ].sample,
      waiting_depot: @all_depots.sample,
      waiting_delivery_cycle: [ @weekly_cycle, @biweekly_cycle ].sample
    )
  end

  def create_support_member!
    create_member!(state: "support", annual_fee: Current.org.annual_fee)
  end

  def create_pending_member!
    create_member!(
      state: "pending",
      waiting_basket_size: [ @small, @medium ].sample,
      waiting_depot: [ @farm_depot, @market_depot ].sample,
      waiting_delivery_cycle: @weekly_cycle
    )
  end

  def create_member!(state:, **attrs)
    name = "#{Faker::Name.unique.first_name} #{Faker::Name.unique.last_name}"
    email = Faker::Internet.unique.email(name: name, domain: EMAIL_DOMAINS.sample)
    phone_prefix = germany? ? "+49" : "+41"

    # For demo-de, half of the members have SEPA direct debit info
    sepa_attrs = if germany? && rand < 0.5
      {
        iban: Faker::Bank.iban(country_code: "de"),
        umr: SecureRandom.alphanumeric(12).upcase,
        signed_on: Date.current - rand(30..365).days
      }
    end

    member = Member.create!(
      name: name,
      emails: email,
      phones: "#{phone_prefix} #{rand(70..79)} #{rand(100..999)} #{rand(10..99)} #{rand(10..99)}",
      street: Faker::Address.unique.street_address,
      zip: Faker::Address.unique.zip,
      city: Faker::Address.unique.city,
      country_code: Current.org.country_code,
      language: Current.org.languages.sample,
      state: state,
      annual_fee: Current.org.annual_fee,
      **attrs
    )

    if sepa_attrs
      member.sepa_mandates.create!(
        iban: sepa_attrs[:iban],
        umr: sepa_attrs[:umr],
        signed_on: sepa_attrs[:signed_on],
        source: "admin")
    end

    member
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to create member: #{e.message}")
    retry
  end

  def seed_membership_history!
    fy2, fy1, fy0 = seed_fiscal_years

    founding_fy2 = @founding_members.map { |member| create_membership!(member, fiscal_year: fy2) }
    @year_minus_two_churned.each_with_index do |member, index|
      create_membership!(member, fiscal_year: fy2, early_exit: index < EARLY_EXITS_PER_CHURN_YEAR)
    end

    founding_fy1 = @founding_members.zip(founding_fy2).map { |member, previous|
      create_membership!(member, fiscal_year: fy1, previous: previous)
    }
    joiners_fy1 = @year_minus_one_joiners.map { |member|
      create_membership!(member, fiscal_year: fy1, late_start: rand < 0.3)
    }
    @year_minus_one_churned.each_with_index do |member, index|
      create_membership!(member, fiscal_year: fy1, early_exit: index < EARLY_EXITS_PER_CHURN_YEAR)
    end
    founding_fy2.zip(founding_fy1).each { |previous, current| mark_renewed!(previous, current) }

    founding_fy0 = @founding_members.zip(founding_fy1).map { |member, previous|
      create_membership!(member, fiscal_year: fy0, previous: previous)
    }
    joiners_current = @year_minus_one_joiners.zip(joiners_fy1).map { |member, previous|
      create_membership!(member, fiscal_year: fy0, previous: previous)
    }
    @current_year_joiners.each { |member|
      create_membership!(member, fiscal_year: fy0, late_start: rand < 0.4)
    }
    founding_fy1.zip(founding_fy0).each { |previous, current| mark_renewed!(previous, current) }
    joiners_fy1.zip(joiners_current).each { |previous, current| mark_renewed!(previous, current) }
  end

  def create_membership!(member, fiscal_year: Current.fiscal_year, previous: nil, early_exit: false, late_start: false)
    basket_size, depot, delivery_cycle, extra, division = membership_config_for(fiscal_year, previous)
    deliveries = delivery_cycle.deliveries(fiscal_year.year)
    raise "No deliveries for #{fiscal_year.year} (#{delivery_cycle.name})" if deliveries.empty?

    started_on =
      if late_start && deliveries.size > 4
        deliveries[rand(1...(deliveries.size / 3))].date
      else
        fiscal_year.beginning_of_year
      end

    ended_on =
      if early_exit && deliveries.size > 6
        deliveries[-(deliveries.size / 3)].date
      else
        fiscal_year.end_of_year
      end

    membership = Membership.create!(
      member: member,
      basket_size: basket_size,
      basket_size_price: basket_size_price_for(basket_size, fiscal_year),
      basket_price_extra: extra,
      depot: depot,
      depot_price: depot.price,
      delivery_cycle: delivery_cycle,
      delivery_cycle_price: delivery_cycle.price,
      started_on: started_on,
      ended_on: ended_on,
      billing_year_division: division
    )

    add_membership_complement!(membership, fiscal_year, previous)
    membership
  end

  def membership_config_for(fiscal_year, previous)
    offset = fy_offset(fiscal_year)
    if previous
      basket_size = rand < 0.3 ? upgrade_basket_size(previous.basket_size) : previous.basket_size
      depot = rand < 0.8 ? previous.depot : depot_for_offset(offset)
      delivery_cycle =
        if depot.delivery_cycles.include?(previous.delivery_cycle) && rand < 0.8
          previous.delivery_cycle
        else
          depot.delivery_cycles.sample
        end
      extra = extra_for_offset(offset, previous: previous)
      division = rand < 0.2 ? division_for_offset(offset) : previous.billing_year_division
    else
      basket_size = size_for_offset(offset)
      depot = depot_for_offset(offset)
      delivery_cycle = depot.delivery_cycles.sample
      extra = extra_for_offset(offset)
      division = division_for_offset(offset)
    end
    [ basket_size, depot, delivery_cycle, extra, division ]
  end

  def size_for_offset(offset)
    weights =
      case offset
      when 2 then { @small => 5, @medium => 3, @large => 1 }
      when 1 then { @small => 3, @medium => 4, @large => 2 }
      else { @small => 2, @medium => 3, @large => 3 }
      end
    pick_weighted(weights)
  end

  def depot_for_offset(offset)
    weights =
      case offset
      when 2 then { @farm_depot => 5, @market_depot => 3, @home_depot => 1 }
      when 1 then { @farm_depot => 3, @market_depot => 3, @home_depot => 2 }
      else { @farm_depot => 2, @market_depot => 3, @home_depot => 3 }
      end
    pick_weighted(weights)
  end

  def extra_for_offset(offset, previous: nil)
    extras = Current.org[:basket_price_extras].map(&:to_f)
    return previous.basket_price_extra.to_f if previous && rand < 0.7

    weights =
      case offset
      when 2 then extras.each_with_index.to_h { |extra, index| [ extra, index.zero? ? 5 : 1 ] }
      when 1 then extras.each_with_index.to_h { |extra, index| [ extra, [ 4 - index, 1 ].max ] }
      else extras.each_with_index.to_h { |extra, index| [ extra, index + 1 ] }
      end
    pick_weighted(weights)
  end

  def division_for_offset(offset)
    weights =
      case offset
      when 2 then { 1 => 5, 4 => 2, 12 => 1 }
      when 1 then { 1 => 3, 4 => 3, 12 => 2 }
      else { 1 => 2, 4 => 3, 12 => 3 }
      end
    pick_weighted(weights)
  end

  def upgrade_basket_size(size)
    return @medium if size.id == @small.id
    return @large if size.id == @medium.id

    size
  end

  def basket_size_price_for(basket_size, fiscal_year)
    (basket_size.price * (1 - (0.05 * fy_offset(fiscal_year)))).round(2)
  end

  def add_membership_complement!(membership, fiscal_year, previous)
    previous_complement = previous&.memberships_basket_complements&.first
    keep = previous_complement && rand < 0.7
    chance = { 2 => 0.2, 1 => 0.3 }.fetch(fy_offset(fiscal_year), 0.45)
    return unless keep || rand < chance

    MembershipsBasketComplement.create!(
      membership: membership,
      basket_complement: keep ? previous_complement.basket_complement : @all_complements.sample,
      quantity: 1
    )
  end

  def mark_renewed!(previous, current)
    previous.update_columns(
      renew: true,
      renewed_at: current.created_at,
      renewal_opened_at: nil)
  end

  def seed_absences!
    log "Seeding absences..."

    seed_fiscal_years.each do |fy|
      memberships = Membership.during_year(fy).to_a
      next if memberships.size < ABSENCES_PER_YEAR

      memberships.sample(ABSENCES_PER_YEAR).each do |membership|
        deliveries = membership.deliveries.order(:date).select { |delivery|
          fy.range.cover?(delivery.date)
        }
        next if deliveries.size < 3

        start_index = rand(0...(deliveries.size - 3))
        end_index = [ start_index + rand(1..2), deliveries.size - 1 ].min

        Absence.create!(
          member: membership.member,
          started_on: deliveries[start_index].date,
          ended_on: deliveries[end_index].date,
          admin: true
        )
      end
    end
  end

  def seed_newsletter!
    log "Seeding newsletter..."

    return if @active_members.blank?

    # Find the "Simple Text" template (first one created by default)
    template = Newsletter::Template.first
    return unless template

    # Build subjects for all languages
    subjects = translated_text("News from the farm")

    # Build block attributes for all languages
    block_attributes = { "0" => { block_id: "text" } }
    Current.org.languages.each do |locale|
      block_attributes["0"]["content_#{locale}"] = translated_text("newsletter_content")[locale]
    end

    # Create the newsletter
    newsletter = Newsletter.create!(
      template: template,
      subjects: subjects,
      audience: "member_state::all",
      blocks_attributes: block_attributes)

    # Send the newsletter (marks it as sent and creates deliveries)
    newsletter.send!
  end

  # Creates a few email suppressions so newsletters and template deliveries
  # have realistic suppressed/excluded emails in the demo.
  # Must run before seed_newsletter! and seed_mail_deliveries!.
  def seed_email_suppressions!
    log "Seeding email suppressions..."

    return if @active_members.size < 2

    # Pick two members from the end of the list (not used in seed_mail_deliveries!)
    members = @active_members.last(2)

    # Broadcast ManualSuppression — member unsubscribed from newsletters.
    # Newsletter deliveries to this email will be marked as suppressed.
    EmailSuppression.create!(
      email: members[0].emails_array.first,
      stream_id: "broadcast",
      reason: "ManualSuppression",
      origin: "Recipient")

    # Outbound HardBounce — transactional email bounced.
    # This email is excluded from active_emails, so template
    # deliveries won't create an Email child for this address.
    EmailSuppression.create!(
      email: members[1].emails_array.first,
      stream_id: "outbound",
      reason: "HardBounce",
      origin: "Recipient")
  end

  # Creates template MailDelivery records for demo variety.
  # Uses deliver! directly on templates (bypasses active check) so we
  # don't need to activate templates that have automatic after_commit
  # callbacks (e.g. absence_created) which would cause duplicates.
  def seed_mail_deliveries!
    log "Seeding mail deliveries..."

    return if @active_members.blank?

    # Activate a few templates so they appear active in the admin UI
    %w[member_validated membership_renewal].each do |title|
      MailTemplate.find_by(title: title)&.update!(active: true)
    end

    members = @active_members.first(5)

    # invoice_created (always active) — use seeded invoices
    template = MailTemplate.find_by!(title: "invoice_created")
    Invoice.where.not(sent_at: nil).limit(3).each do |invoice|
      template.deliver!(invoice: invoice)
    end

    # member_validated — a few active members
    template = MailTemplate.find_by!(title: "member_validated")
    members.first(3).each do |member|
      template.deliver!(member: member)
    end

    # absence_created (not activated — avoids duplicate from Absence after_commit)
    template = MailTemplate.find_by!(title: "absence_created")
    Absence.limit(2).each do |absence|
      template.deliver!(absence: absence)
    end

    # membership_renewal
    template = MailTemplate.find_by!(title: "membership_renewal")
    members.first(2).each do |member|
      next unless (membership = member.current_membership)

      template.deliver!(membership: membership)
    end
  end

  # Must run outside of transaction so after_create_commit on
  # MailDelivery::Email fires and ProcessJobs are enqueued.
  # Tries to process each email (renders message, stores preview on
  # parent MailDelivery), then marks as delivered for demo display.
  # DemoMailInterceptor blocks actual email sending.
  #
  # ActiveStorage defers S3 uploads to after_commit, so invoice PDFs
  # may not yet be available when this runs. Rescue and skip process!
  # in that case — the preview is nice-to-have, delivered state is not.
  def mark_deliveries_delivered!
    MailDelivery::Email.find_each do |email|
      next unless email.processing?

      begin
        email.process!
        email.reload
      rescue ActiveStorage::FileNotFoundError
        # PDF not yet on S3; skip preview, just mark delivered below.
      end
      email.delivered!(at: 1.week.ago) if email.processing?
    end
  end

  def seed_invoices_and_payments!
    log "Seeding invoices and payments..."

    return if @active_members.blank?

    # Create some "Other" type invoices for variety
    create_other_invoices!

    # Create extra payments for some members so they have credit balances
    # This simulates members who paid in advance before their membership invoices are created
    create_advance_payments!
  end

  def create_other_invoices!
    invoice_items = [
      { description: { "en" => "Workshop materials", "fr" => "Matériel d'atelier", "de" => "Workshop-Material" }, amount: 25 },
      { description: { "en" => "Extra vegetables", "fr" => "Légumes supplémentaires", "de" => "Extra Gemüse" }, amount: 15 },
      { description: { "en" => "Preserving jars", "fr" => "Bocaux de conserve", "de" => "Einmachgläser" }, amount: 30 },
      { description: { "en" => "Recipe book", "fr" => "Livre de recettes", "de" => "Rezeptbuch" }, amount: 20 },
      { description: { "en" => "Farm visit donation", "fr" => "Don visite de la ferme", "de" => "Spende Hofbesuch" }, amount: 50 }
    ]

    sepa_members = germany? ? @active_members.select(&:sepa?) : []

    seed_fiscal_years.each do |fy|
      members = members_with_membership_in(fy)
      next if members.empty?

      count = fy.past? ? 3 : invoice_items.size
      count.times do |i|
        item_data = invoice_items[i % invoice_items.size]
        member = if i.zero? && sepa_members.any? && members.include?(sepa_members.first)
          sepa_members.first
        else
          members[i % members.size]
        end

        description = item_data[:description][Current.org.default_locale] || item_data[:description]["en"]
        invoice_date = random_date_in_year(fy, latest: Date.current - 10.days)
        next unless invoice_date

        invoice = Invoice.new(
          member: member,
          date: invoice_date,
          sent_at: invoice_date
        )
        invoice[:entity_type] = "Other"
        invoice[:amount] = item_data[:amount]
        invoice[:vat_rate] = 0
        invoice[:vat_amount] = 0

        next unless invoice.save

        InvoiceItem.create!(
          invoice: invoice,
          description: description,
          amount: item_data[:amount]
        )
        invoice.process!(send_email: false)

        # Closed years are fully paid. Current year keeps a partial and an unpaid invoice.
        pay_other_invoice!(invoice, member, invoice_date, item_data[:amount], i, fy)
      end
    end
  end

  def pay_other_invoice!(invoice, member, invoice_date, amount, index, fy)
    fully_paid = fy.past? || index < 3
    partially_paid = !fy.past? && index == 3
    return unless fully_paid || partially_paid

    payment_amount = fully_paid ? amount : (amount * 0.5).round
    payment_date = [ invoice_date + rand(5..20).days, Date.current ].min
    payment_date = invoice_date if payment_date < invoice_date

    Payment.create!(
      member: member,
      invoice: invoice,
      amount: payment_amount,
      date: payment_date,
      origin: "camt"
    )
  end

  def create_advance_payments!
    # Ensure payment date falls within the current fiscal year
    fiscal_year = Current.fiscal_year
    earliest_date = fiscal_year.beginning_of_year
    latest_date = [ Date.current - 5.days, earliest_date ].max
    # Use a range within the fiscal year, even if it means using today
    payment_range = earliest_date..[ latest_date, Date.current ].min

    # Select a few members to have advance payments (credit balance)
    members_with_credit = @active_members.sample(3)

    members_with_credit.each_with_index do |member, i|
      payment_date = rand(payment_range)
      # Varying amounts to show different credit balances
      amount = [ 200, 350, 500 ][i]

      Payment.create!(
        member: member,
        amount: amount,
        date: payment_date,
        origin: "manual"
      )
    end
  end

  def seed_basket_contents!
    log "Seeding basket contents..."

    deliveries = seed_deliveries_for_contents
    return if @products.blank? || deliveries.blank?

    deliveries_with_baskets = deliveries.select { |delivery| delivery.baskets.active.any? }
    return if deliveries_with_baskets.empty?

    basket_sizes = BasketSize.paid.reorder(:id)
    return if basket_sizes.empty?

    eligible_for_coverage = deliveries_with_baskets.select { |delivery|
      delivery.date <= 1.week.from_now
    }
    deliveries_to_fill = eligible_for_coverage.group_by { |delivery|
      Analytics.year_for(delivery.date)
    }.flat_map { |year, year_deliveries|
      rate = CONTENTS_COVERAGE_BY_OFFSET.fetch(fy_offset_for_year(year), 0.90)
      fill_count = [ (year_deliveries.size * rate).ceil, 1 ].max
      year_deliveries.sort_by(&:date).first(fill_count)
    }
    deliveries_to_fill.concat(basket_content_deliveries_to_always_fill(deliveries_with_baskets))

    deliveries_to_fill.uniq(&:id).each { |delivery| fill_basket_content!(delivery, basket_sizes) }
  end

  def seed_deliveries_for_contents
    if @deliveries_by_year.present?
      @deliveries_by_year.values.flatten
    else
      Array(@current_year_deliveries)
    end
  end

  # Basket contents defaults to Delivery.next; prev is the last past delivery.
  # Coverage fills from the start of each year, so those two are often in the
  # unfilled tail unless we add them explicitly.
  def basket_content_deliveries_to_always_fill(candidates)
    last_past = candidates.select { |delivery| delivery.date <= Date.current }.max_by(&:date)
    upcoming = candidates.select { |delivery| delivery.date > Date.current }.min_by(&:date)
    [ last_past, upcoming ].compact
  end

  def fill_basket_content!(delivery, basket_sizes)
    total_price = basket_sizes.sum(&:price)
    @products.sample(6).each do |product|
      base_qty = product.unit == "kg" ? rand(1700..2000) : rand(9..12)
      quantities = basket_sizes.each_with_object({}) do |bs, hash|
        ratio = bs.price / total_price.to_f
        qty = (base_qty * ratio).round
        hash[bs.id.to_s] = qty if qty > 0
      end

      if quantities.empty?
        largest_basket_size = basket_sizes.max_by(&:price)
        quantities[largest_basket_size.id.to_s] = [ base_qty, 1 ].max
      end

      BasketContent.create!(
        delivery: delivery,
        product: product,
        unit_price: product.default_price,
        depot_ids: @all_depots.map(&:id),
        basket_size_ids_quantities: quantities
      )
    end
  end

  def seed_activities!
    log "Seeding activities..."

    @activities = []

    presets = ActivityPreset.all.to_a
    return if presets.empty?

    hour_work = Current.org.activity_i18n_scope == "hour_work"

    seed_fiscal_years.each do |fy|
      range_end = [ fy.end_of_year, Date.current - 1.day ].min
      range_start = fy.beginning_of_year + 1.month
      next if range_start > range_end

      create_activities_for_period!(
        presets: presets,
        hour_work: hour_work,
        start_date: range_start,
        count: fy.past? ? 10 : 8,
        max_date: range_end
      )
    end

    create_activities_for_period!(
      presets: presets,
      hour_work: hour_work,
      start_date: Date.current + 1.day,
      count: 8
    )

    seed_activity_participations!
  end

  def create_activities_for_period!(presets:, hour_work:, start_date:, count:, max_date: nil)
    date = start_date
    date += 1.day while date.saturday? || date.sunday?
    spacing =
      if max_date
        [ ((max_date - date).to_i / [ count, 1 ].max), 14 ].max
      end

    count.times do
      break if max_date && date > max_date

      preset = presets.sample

      if hour_work
        [ 9, 10, 11 ].each do |hour|
          activity = Activity.new(
            date: date,
            start_time: Tod::TimeOfDay.new(hour),
            end_time: Tod::TimeOfDay.new(hour + 1),
            titles: preset.titles,
            places: preset.places,
            place_urls: preset.place_urls,
            participants_limit: rand(4..10)
          )
          activity.save!(validate: date >= Date.current)
          @activities << activity
        end
      else
        activity = Activity.new(
          date: date,
          start_time: Tod::TimeOfDay.parse("9:00"),
          end_time: Tod::TimeOfDay.parse("12:00"),
          titles: preset.titles,
          places: preset.places,
          place_urls: preset.place_urls,
          participants_limit: rand(4..10)
        )
        activity.save!(validate: date >= Date.current)
        @activities << activity
      end

      date += spacing || rand(3..7).days
      date += 1.day while date.saturday? || date.sunday?
    end
  end

  def seed_activity_participations!
    log "Seeding activity participations..."

    return if @activities.blank?

    past, upcoming = @activities.partition { |activity| activity.date < Date.current }
    activities_to_fill = past + upcoming.sample([ upcoming.size / 2, 1 ].max)

    activities_to_fill.each do |activity|
      members = members_with_demanded_participations_on(activity.date)
      next if members.empty?

      max_participants = [ activity.participants_limit || 4, members.size ].min
      participants_count =
        if activity.date < Date.current
          [ 3, max_participants ].min
        else
          rand(1..max_participants)
        end

      members.sample(participants_count).each do |member|
        next if ActivityParticipation.exists?(activity: activity, member: member)

        participation = ActivityParticipation.new(
          activity: activity,
          member: member,
          participants_count: 1
        )

        if activity.date < Date.current
          participation.save!(validate: false)
          if rand < 0.85
            participation.update_columns(
              state: "validated",
              validated_at: activity.date + rand(1..3).days
            )
          end
        else
          participation.save!
        end
      end
    end
  end

  def seed_shop!
    log "Seeding shop..."

    return if @shop_products.blank? || @active_members.blank?

    seed_coming_shop_orders!
    seed_historical_shop_orders!
  end

  def seed_coming_shop_orders!
    shop_deliveries = Delivery.where(shop_open: true).order(:date)
    delivery = shop_deliveries.coming.first || shop_deliveries.where(date: Date.current..).first
    return unless delivery

    members_to_order = @active_members.sample([ @active_members.size / 2, 3 ].max)
    members_to_order.each do |member|
      order = build_shop_order(member, delivery, quantity: rand(1..3))
      next unless order

      order.save!
      order.confirm! if rand < 0.8
    end
  end

  def seed_historical_shop_orders!
    Delivery.where(shop_open: true).where(date: ...Date.current).order(:date).each do |delivery|
      members = members_with_basket_on(delivery)
      next if members.empty?

      members.sample([ 4, members.size ].min).each do |member|
        next if Shop::Order.exists?(member: member, delivery: delivery)

        order = build_shop_order(member, delivery, quantity: 1)
        next unless order

        order.save!
        order.confirm!
        invoice = order.invoice!
        invoice.update_columns(date: delivery.date, sent_at: delivery.date)
        invoice.process!(send_email: false)
        invoice.reload

        payment_date = [ delivery.date + rand(5..20).days, Date.current ].min
        Payment.create!(
          member: member,
          invoice: invoice,
          amount: invoice.amount,
          date: payment_date,
          origin: "camt"
        )
      end
    end
  end

  def build_shop_order(member, delivery, quantity:)
    return if Shop::Order.exists?(member: member, delivery: delivery)

    order = Shop::Order.new(
      member: member,
      delivery: delivery,
      state: Shop::Order::CART_STATE
    )

    @shop_products.sample(rand(1..3)).each do |product|
      variant = product.variants.available.sample
      next unless variant
      next if variant.out_of_stock?

      max_qty = [ quantity, variant.stock ].min
      next unless max_qty.positive?

      order.items.build(
        product: product,
        product_variant: variant,
        item_price: variant.price,
        quantity: max_qty
      )
    end

    order.items.any? ? order : nil
  end

  # def default_email_signature
  #   { @org_language => I18n.t("organization.default_email_signature", locale: @org_language) + "\nCSA Admin Demo" }
  # end

  # def default_email_footer
  #   creditor = CREDITOR_INFO[@org_language]
  #   { @org_language => I18n.t("organization.default_email_footer", locale: @org_language) + "\n#{creditor[:name]}, #{creditor[:street]}, #{creditor[:city]} #{creditor[:zip]}" }
  # end

  def seed_fiscal_years
    @seed_fiscal_years ||= begin
      current = Current.fiscal_year
      (0...HISTORICAL_YEAR_COUNT).map { |index|
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

  # Returns a hash with translations for all org languages
  def translated_text(key)
    Current.org.languages.index_with do |lang|
      TRANSLATIONS.dig(key, lang) || key
    end
  end

  # Returns a simple hash with the same value for all languages
  def simple_localized_text(text)
    Current.org.languages.index_with { |_| text }
  end

  # Logs a message, using puts in console to avoid duplicate output
  def log(message)
    if defined?(Rails::Console)
      puts "[Demo::Seeder] #{message}"
    else
      Rails.logger.info "[Demo::Seeder] #{message}"
    end
  end
end
