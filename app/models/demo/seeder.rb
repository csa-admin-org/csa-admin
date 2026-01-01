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
# 4. Populates with realistic demo members and memberships
# 5. Adds basket content, invoices, and payments for realism
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
  CREDITOR_INFO = {
    "en" => { name: "Demo Farm", street: "42 Farm Street", zip: "2300", city: "La Chaux-de-Fonds" },
    "fr" => { name: "Ferme Démo", street: "Rue de la Ferme 42", zip: "2300", city: "La Chaux-de-Fonds" },
    "de" => { name: "Demo Bauernhof", street: "Hofstrasse 42", zip: "2300", city: "La Chaux-de-Fonds" }
  }.freeze

  # Member counts for seeding
  ACTIVE_MEMBERS_COUNT = 20
  TRIAL_MEMBERS_COUNT = 3
  WAITING_MEMBERS_COUNT = 3
  SUPPORT_MEMBERS_COUNT = 2
  PENDING_MEMBERS_COUNT = 2

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
      seed_absences!
      seed_newsletter!
      seed_invoices_and_payments!
      seed_basket_contents!
      seed_activities!
      seed_shop!
    end
    mark_newsletter_delivered!

    log "Demo reset completed successfully"
  end

  private

  def reset_organization_settings!
    log "Resetting organization settings..."

    org = Organization.instance

    # Features to exclude (require additional configuration)
    excluded_features = %i[local_currency bidding_round new_member_fee]
    enabled_features = (Organization::FEATURES - excluded_features).map(&:to_s)

    org.update!(
      name: "CSA Admin Demo",

      # Enable most features for demo (excluding those requiring extra config)
      features: enabled_features,

      # Single language matching the demo tenant
      languages: [ @org_language ],
      phone: nil,
      email: "info@csa-admin.org",
      email_default_from: "info@#{@org_domain}",

      # Creditor info (for invoices)
      creditor_name: creditor_info[:name],
      creditor_street: creditor_info[:street],
      creditor_zip: creditor_info[:zip],
      creditor_city: creditor_info[:city],
      currency_code: "CHF",

      # ============================================
      # Billing settings (billing tab)
      # ============================================
      recurring_billing_wday: 1,
      billing_year_divisions: [ 1, 4, 12 ],
      trial_baskets_count: 2,
      send_closed_invoice: false,
      billing_starts_after_first_delivery: true,
      billing_ends_on_last_delivery_fy_month: false,
      sepa_creditor_identifier: nil,
      bank_reference: nil,

      # Invoice settings
      iban: "CH5530024123456789012",
      # invoice_infos: {},
      invoice_sepa_infos: {},
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
      # Member account settings (member_account tab)
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
        activity_participations_demanded_annually
        activity_participations_annual_price_change
        absences_included_annually
      ],
      membership_renewal_depot_update: true,

      # ============================================
      # Delivery PDF settings
      # ============================================
      delivery_pdf_footers: {},
      delivery_pdf_member_info: "none",

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
      basket_price_extra_labels: {
        "en" => "{% if extra == 0 %}\nBase price\n{% elsif extra == 1.5 %}\n+ {{ extra }}/basket\n{% else %}\n+ {{ extra | ceil }}.-/basket\n{% endif %}",
        "fr" => "{% if extra == 0 %}\nTarif de base\n{% elsif extra == 1.5 %}\n+ {{ extra }}/panier\n{% else %}\n+ {{ extra | ceil }}.-/panier\n{% endif %}",
        "de" => "{% if extra == 0 %}\nBasispreis\n{% elsif extra == 1.5 %}\n+ {{ extra }}/Tasche\n{% else %}\n+ {{ extra | ceil }}.-/Tasche\n{% endif %}"
      },
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
    org.save!

    # Clear rich text fields (ActionText)
    clear_organization_rich_texts!(org)
  end

  def creditor_info
    CREDITOR_INFO.fetch(@org_language)
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

      # Shop orders
      Shop::OrderItem.delete_all
      Shop::Order.delete_all

      # Newsletters
      Newsletter::Delivery.delete_all
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
      week_numbers: :even,
      absences_included_annually: 1,
      periods_attributes: [ { from_fy_month: 4, to_fy_month: 11 } ]
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
    current_fy = Current.fiscal_year

    # Create deliveries for the full current fiscal year (including past dates)
    # This gives a complete picture of the year for demo purposes
    @current_year_deliveries = create_deliveries_for_year!(current_fy)
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
        delivery = Delivery.new(date: date)
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
        default_unit: product_data[:unit],
        default_unit_price: product_data[:price]
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
          stock: rand(10..20)
        )
      end

      product.save!
      product
    end

    # Mark some deliveries as shop_open (coming or recent past)
    deliveries_to_open = Delivery.coming.limit(8)
    if deliveries_to_open.empty?
      # No coming deliveries, use the most recent past deliveries
      deliveries_to_open = Delivery.order(date: :desc).limit(8)
    end
    deliveries_to_open.each do |delivery|
      delivery.shop_open = true
      delivery.save!(validate: delivery.date >= Date.current)
    end
  end

  def seed_members!
    log "Seeding members..."

    @active_members = []
    ACTIVE_MEMBERS_COUNT.times { @active_members << create_active_member! }
    TRIAL_MEMBERS_COUNT.times { @active_members << create_trial_member! }
    WAITING_MEMBERS_COUNT.times { create_waiting_member! }
    SUPPORT_MEMBERS_COUNT.times { create_support_member! }
    PENDING_MEMBERS_COUNT.times { create_pending_member! }
  end

  def create_active_member!
    member = create_member!(state: "active", trial_baskets_count: 0)
    create_membership!(member)
    member
  end

  def create_trial_member!
    member = create_member!(state: "active")
    create_membership!(member)
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

    Member.create!(
      name: name,
      emails: email,
      phones: "+41 #{rand(70..79)} #{rand(100..999)} #{rand(10..99)} #{rand(10..99)}",
      street: Faker::Address.unique.street_address,
      zip: Faker::Address.unique.zip,
      city: Faker::Address.unique.city,
      country_code: Current.org.country_code,
      language: Current.org.languages.sample,
      state: state,
      annual_fee: Current.org.annual_fee,
      **attrs
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to create member: #{e.message}")
    retry
  end

  def create_membership!(member)
    current_fy = Current.fiscal_year
    basket_size = [ @small, @medium, @large ].sample
    depot = @all_depots.sample
    delivery_cycle = depot.delivery_cycles.sample

    # Membership starts at beginning of fiscal year (or random delivery date)
    started_on = rand < 0.15 ? delivery_cycle.deliveries(current_fy).sample.date : current_fy.beginning_of_year

    membership = Membership.create!(
      member: member,
      basket_size: basket_size,
      basket_size_price: basket_size.price,
      basket_price_extra: Current.org[:basket_price_extras].sample.to_f,
      depot: depot,
      depot_price: depot.price,
      delivery_cycle: delivery_cycle,
      delivery_cycle_price: delivery_cycle.price,
      started_on: started_on,
      ended_on: current_fy.end_of_year,
      billing_year_division: [ 1, 4, 12 ].sample
    )

    # Add basket complements to some memberships
    if rand < 0.4
      MembershipsBasketComplement.create!(
        membership: membership,
        basket_complement: @all_complements.sample,
        quantity: 1
      )
    end

    membership
  end

  def seed_absences!
    log "Seeding absences..."

    return if @active_members.blank?

    # Create 3 absences for random active members
    members_with_absences = @active_members.sample(3)

    members_with_absences.each do |member|
      membership = member.memberships.current&.first
      next unless membership

      deliveries = membership.deliveries.order(:date)
      next if deliveries.size < 3

      # Pick a random range of 1-3 consecutive deliveries
      start_index = rand(0...(deliveries.size - 3))
      end_index = [ start_index + rand(1..2), deliveries.size - 1 ].min

      Absence.create!(
        member: member,
        started_on: deliveries[start_index].date,
        ended_on: deliveries[end_index].date,
        admin: true # Skip notice period validation
      )
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

  # Must run outside of transaction
  def mark_newsletter_delivered!
    Newsletter::Delivery.find_each do |delivery|
      delivery.delivered!(at: 1.week.ago)
    end
  end

  def seed_invoices_and_payments!
    log "Seeding invoices and payments..."

    return if @active_members.blank?

    # Create some "Other" type invoices for variety
    create_other_invoices!
  end

  def create_other_invoices!
    invoice_items = [
      { description: { "en" => "Workshop materials", "fr" => "Matériel d'atelier" }, amount: 25 },
      { description: { "en" => "Extra vegetables", "fr" => "Légumes supplémentaires" }, amount: 15 },
      { description: { "en" => "Preserving jars", "fr" => "Bocaux de conserve" }, amount: 30 },
      { description: { "en" => "Recipe book", "fr" => "Livre de recettes" }, amount: 20 },
      { description: { "en" => "Farm visit donation", "fr" => "Don visite de la ferme" }, amount: 50 }
    ]

    # Create 5 "Other" invoices spread across active members
    invoice_items.each_with_index do |item_data, i|
      member = @active_members[i % @active_members.size]
      next unless member

      description = item_data[:description][Current.org.default_locale] || item_data[:description]["en"]
      invoice_date = Date.current - rand(10..60).days

      invoice = Invoice.new(
        member: member,
        date: invoice_date,
        sent_at: invoice_date
      )
      invoice[:entity_type] = "Other"
      invoice[:amount] = item_data[:amount]
      invoice[:vat_rate] = 0
      invoice[:vat_amount] = 0

      if invoice.save
        InvoiceItem.create!(
          invoice: invoice,
          description: description,
          amount: item_data[:amount]
        )

        # Process the invoice immediately (normally async) so it's visible in UI
        invoice.process!(send_email: false)

        # Create payment for some invoices with explicit invoice reference
        if i < 3 # First 3 invoices are fully paid
          Payment.create!(
            member: member,
            invoice: invoice,
            amount: item_data[:amount],
            date: invoice_date + rand(5..20).days
          )
        elsif i == 3 # Fourth invoice is partially paid
          Payment.create!(
            member: member,
            invoice: invoice,
            amount: (item_data[:amount] * 0.5).round,
            date: invoice_date + rand(5..15).days
          )
        end
        # Fifth invoice remains unpaid
      end
    end
  end

  def seed_basket_contents!
    log "Seeding basket contents..."

    return if @products.blank? || @current_year_deliveries.blank?

    # Find deliveries that have active baskets (from memberships)
    deliveries_with_baskets = @current_year_deliveries.reverse.select do |delivery|
      delivery.baskets.active.any?
    end

    return if deliveries_with_baskets.empty?

    # Add basket content to the first few deliveries with baskets
    deliveries_to_fill = deliveries_with_baskets.first(5)

    # Get basket size IDs for setting up basket content
    basket_sizes = BasketSize.paid.reorder(:id)
    return if basket_sizes.empty?

    basket_size_ids = basket_sizes.map(&:id)
    # Pro-rate percentages based on price
    total_price = basket_sizes.sum(&:price)
    percentages = basket_sizes.map { |bs| ((bs.price / total_price.to_f) * 100).round }
    # Adjust to ensure sum is 100
    percentages[-1] += 100 - percentages.sum if percentages.sum != 100

    # Build percentages hash for basket_size_ids_percentages setter
    percentages_hash = basket_size_ids.zip(percentages).to_h { |id, pct| [ id.to_s, pct ] }

    deliveries_to_fill.each do |delivery|
      # Add 6 products per delivery
      products_for_delivery = @products.sample(6)

      products_for_delivery.each do |product|
        # Calculate quantity based on number of baskets
        base_quantity = product.default_unit == "kg" ? rand(20..25) : rand(40..45)

        BasketContent.create!(
          delivery: delivery,
          product: product,
          quantity: base_quantity,
          unit: product.default_unit,
          unit_price: product.default_unit_price,
          depot_ids: @all_depots.map(&:id),
          distribution_mode: "automatic",
          basket_size_ids_percentages: percentages_hash
        )
      end
    end
  end

  def seed_activities!
    log "Seeding activities..."

    @activities = []

    presets = ActivityPreset.all.to_a
    return if presets.empty?

    # When org uses "hour_work" scope, each activity must be exactly 1 hour
    hour_work = Current.org.activity_i18n_scope == "hour_work"

    # Create past activities (for validated participations)
    create_activities_for_period!(
      presets: presets,
      hour_work: hour_work,
      start_date: Date.current - 3.months,
      count: 8
    )

    # Create future activities (for upcoming participations)
    create_activities_for_period!(
      presets: presets,
      hour_work: hour_work,
      start_date: Date.current + 1.day,
      count: 8
    )

    # Create activity participations for some members
    seed_activity_participations!
  end

  def create_activities_for_period!(presets:, hour_work:, start_date:, count:)
    date = start_date
    # Skip to weekday if starting on weekend
    date += 1.day while date.saturday? || date.sunday?

    count.times do
      preset = presets.sample

      if hour_work
        # Create multiple 1-hour slots for the morning
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
          # Skip validation for past activities
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
        # Skip validation for past activities
        activity.save!(validate: date >= Date.current)
        @activities << activity
      end

      # Move to next date, spacing out activities
      date += rand(3..7).days
      date += 1.day while date.saturday? || date.sunday?
    end
  end

  def seed_activity_participations!
    log "Seeding activity participations..."

    return if @activities.blank? || @active_members.blank?

    # Get members with memberships that demand activity participations
    members_with_memberships = @active_members.select do |member|
      member.current_membership&.activity_participations_demanded&.positive?
    end

    return if members_with_memberships.empty?

    # Create participations for about half of the activities
    activities_to_fill = @activities.sample(@activities.size / 2)

    activities_to_fill.each do |activity|
      # Add 1-3 participants per activity
      participants_count = rand(1..[ 3, activity.participants_limit || 3 ].min)

      participants_count.times do
        member = members_with_memberships.sample
        next unless member
        next if ActivityParticipation.exists?(activity: activity, member: member)

        participation = ActivityParticipation.new(
          activity: activity,
          member: member,
          participants_count: 1
        )

        # Skip validation for past activities
        if activity.date < Date.current
          participation.save!(validate: false)
          # Validate some past participations
          if rand < 0.7
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

    # Get deliveries that are shop_open (either coming or recent past)
    shop_deliveries = Delivery.where(shop_open: true).order(:date)
    return if shop_deliveries.empty?

    # Prefer coming delivery, but fall back to past if none available
    delivery = shop_deliveries.coming.first || shop_deliveries.last

    # Create orders for some members
    members_to_order = @active_members.sample([ @active_members.size / 2, 3 ].max)

    members_to_order.each do |member|
      next unless delivery
      next if Shop::Order.exists?(member: member, delivery: delivery)

      # Build order with 1-3 random products
      order = Shop::Order.new(
        member: member,
        delivery: delivery,
        state: Shop::Order::CART_STATE
      )

      products_to_add = @shop_products.sample(rand(1..3))
      products_to_add.each do |product|
        variant = product.variants.available.sample
        next unless variant
        next if variant.out_of_stock?

        order.items.build(
          product: product,
          product_variant: variant,
          item_price: variant.price,
          quantity: rand(1..variant.stock)
        )
      end

      next if order.items.empty?

      order.save!

      # Confirm most orders (move from cart to pending)
      if rand < 0.8
        order.confirm!

        # Invoice some of the confirmed orders (for past deliveries)
        if delivery.date < Date.current && rand < 0.5
          invoice = order.invoice!
          invoice.process!
        end
      end
    end
  end

  # def default_email_signature
  #   { @org_language => I18n.t("organization.default_email_signature", locale: @org_language) + "\nCSA Admin Demo" }
  # end

  # def default_email_footer
  #   creditor = CREDITOR_INFO[@org_language]
  #   { @org_language => I18n.t("organization.default_email_footer", locale: @org_language) + "\n#{creditor[:name]}, #{creditor[:street]}, #{creditor[:city]} #{creditor[:zip]}" }
  # end

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
