# frozen_string_literal: true

module Demo::Seeder::Catalog
  extend ActiveSupport::Concern

  private

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
      wdays: [ 2 ],
      absences_included_annually: 2,
      periods_attributes: [ { from_fy_month: 4, to_fy_month: 11 } ])
    @biweekly_cycle = DeliveryCycle.create!(
      names: translated_text("Bi-weekly"),
      wdays: [ 2 ],
      absences_included_annually: 1,
      periods_attributes: [ { from_fy_month: 4, to_fy_month: 11, results: :even } ])
  end

  def create_basket_sizes!
    @small = BasketSize.create!(
      names: translated_text("Small"),
      public_names: translated_text("Small basket (1-2 people)"),
      price: 22,
      activity_participations_demanded_annually: 2)
    @medium = BasketSize.create!(
      names: translated_text("Medium"),
      public_names: translated_text("Medium basket (3-4 people)"),
      price: 33,
      activity_participations_demanded_annually: 3)
    @large = BasketSize.create!(
      names: translated_text("Large"),
      public_names: translated_text("Large basket (5+ people)"),
      price: 44,
      activity_participations_demanded_annually: 4)
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
      delivery_cycles: [ @weekly_cycle, @biweekly_cycle ])
    @market_depot = Depot.create!(
      names: translated_text("Market"),
      public_names: translated_text("Market stand"),
      price: 2,
      language: Current.org.default_locale,
      street: "Place du Marché",
      zip: "1003",
      city: "Lausanne",
      delivery_cycles: [ @weekly_cycle, @biweekly_cycle ])
    @home_depot = Depot.create!(
      names: translated_text("Home delivery"),
      price: 8,
      language: Current.org.default_locale,
      delivery_sheets_mode: "home_delivery",
      delivery_cycles: [ @weekly_cycle ])
    @all_depots = [ @farm_depot, @market_depot, @home_depot ]
  end

  def create_basket_complements!
    @bread = BasketComplement.create!(names: translated_text("Bread"), price: 6, delivery_ids: [])
    @eggs = BasketComplement.create!(names: translated_text("Eggs"), price: 5, delivery_ids: [])
    @cheese = BasketComplement.create!(names: translated_text("Cheese"), price: 12, delivery_ids: [])
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
    date = fiscal_year.beginning_of_year
    date += (2 - date.wday) % 7
    deliveries = []

    while date <= fiscal_year.end_of_year
      if date.month.between?(4, 11)
        delivery = Delivery.new(date: date, shop_open: false)
        delivery.save!(validate: date >= Date.current)
        deliveries << delivery
      end
      date += 1.week
    end

    attach_complements_to_deliveries!(deliveries)
    deliveries
  end

  def attach_complements_to_deliveries!(deliveries)
    deliveries.each_with_index do |delivery, i|
      complement_ids = []
      complement_ids << @bread.id if i.even?
      complement_ids << @eggs.id if (i % 3).zero?
      next if complement_ids.empty?

      delivery.basket_complement_ids = complement_ids
      delivery.save!(validate: delivery.date >= Date.current)
    end
  end

  def create_basket_content_products!
    @products = Demo::Seeder::PRODUCTS.map do |product_data|
      BasketContent::Product.create!(
        names: translated_text(product_data[:key]),
        unit: product_data[:unit],
        default_price: product_data[:price])
    end
  end

  def create_activity_presets!
    ActivityPreset.create!(
      titles: translated_text("Weeding"),
      places: translated_text("Farm"),
      place_urls: simple_localized_text("https://maps.google.com"))
    ActivityPreset.create!(
      titles: translated_text("Harvest day"),
      places: translated_text("Farm fields"),
      place_urls: simple_localized_text("https://maps.google.com"))
    ActivityPreset.create!(
      titles: translated_text("Market duty"),
      places: translated_text("Town Center"),
      place_urls: simple_localized_text("https://maps.google.com"))
  end

  def create_shop_producers!
    return unless Current.org.feature?("shop")

    @shop_producers = Demo::Seeder::SHOP_PRODUCERS.map do |producer_data|
      ::Shop::Producer.create!(
        name: Demo::Seeder::TRANSLATIONS.dig(producer_data[:key], @org_language),
        website_url: producer_data[:website_url])
    end
  end

  def create_shop_products!
    return unless Current.org.feature?("shop")

    @shop_products = Demo::Seeder::SHOP_PRODUCTS.each_with_index.map do |product_data, index|
      product = ::Shop::Product.new(
        names: translated_text(product_data[:key]),
        available: true,
        producer: @shop_producers[index % @shop_producers.size])
      product_data[:variants].each do |variant_data|
        product.variants.build(
          names: translated_text(variant_data[:key]),
          price: variant_data[:price],
          available: true,
          stock: rand(40..80))
      end
      product.tap(&:save!)
    end
    open_shop_deliveries!
  end

  def open_shop_deliveries!
    deliveries_to_open = Delivery.coming.limit(8)
    deliveries_to_open = Delivery.order(date: :desc).limit(8) if deliveries_to_open.empty?
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
end
