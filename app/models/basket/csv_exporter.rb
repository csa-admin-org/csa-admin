# frozen_string_literal: true

class Basket::CSVExporter
  include ActionView::Helpers::NumberHelper

  def initialize(delivery: nil, fiscal_year: nil)
    raise ArgumentError, "Provide either delivery or fiscal_year" if delivery.nil? && fiscal_year.nil?

    @delivery = delivery
    @fiscal_year = fiscal_year
    @single_delivery = delivery.present?
    @deliveries = load_deliveries
    @basket_complements_exist = BasketComplement.kept.any?
    @shop_orders = load_shop_orders
    @shop_orders_index = @shop_orders.index_by { |o| [ o.member_id, o.delivery_id ] }
    @shop_products = @shop_orders.products_displayed_in_delivery_sheets
  end

  def generate
    CSV.generate do |csv|
      csv << translated_headers
      baskets.find_each do |basket|
        csv << row(basket)
      end
    end
  end

  def filename
    if @single_delivery
      [
        Delivery.model_name.human.downcase,
        @delivery.display_number,
        @delivery.date.strftime("%Y%m%d")
      ].join("-") + ".csv"
    else
      [
        Delivery.model_name.human(count: 2).downcase,
        @fiscal_year.to_s
      ].join("-") + ".csv"
    end
  end

  private

  def load_deliveries
    if @single_delivery
      [ @delivery ]
    else
      Delivery.during_year(@fiscal_year.year).to_a
    end
  end

  def baskets
    @baskets ||= begin
      scope = Basket.deliverable.where(delivery: @deliveries)

      includes = [ :delivery, :basket_size, :depot, baskets_basket_complements: :basket_complement ]
      includes << { membership: :member }

      scope.includes(*includes)
    end
  end

  def translated_headers
    @translated_headers ||= headers.map { |h| h.is_a?(Symbol) ? Basket.human_attribute_name(h) : h }
  end

  def headers
    @headers ||= build_headers
  end

  def build_headers
    cols = []

    unless @single_delivery
      cols << :delivery_id
      cols << :delivery_date
    end

    cols << :basket_id
    cols << :membership_id
    cols << :member_id

    if @single_delivery
      cols << :name
      cols << :emails
      cols << :phones
      cols << :street
      cols << :zip
      cols << :city
      cols << :food_note
      cols << :delivery_note
    end

    cols << :depot_id
    cols << :depot
    cols << :depot_price
    cols << :basket_size_id
    cols << I18n.t("attributes.basket_size")
    cols << :quantity
    cols << :basket_size_price
    cols << :state
    cols << :absence_id
    cols << :provisionally_absent
    cols << Current.org.basket_price_extra_title if feature?("basket_price_extra")
    cols << :description

    if @basket_complements_exist
      complement_columns.each { |c| cols << c.name }
      cols << "#{Basket.human_attribute_name(:complement_ids)} (#{Basket.human_attribute_name(:description)})"
      cols << :complements_price
    end

    if feature?("shop")
      cols << I18n.t("shop.title_orders", count: 2)
      if @basket_complements_exist
        cols << "#{Basket.human_attribute_name(:complement_ids)} (#{Shop::Order.model_name.human(count: 1)})"
      end
      @shop_products.each { |p| cols << "#{p.name_with_single_variant} (#{I18n.t('shop.title')})" }
    end

    cols.freeze
  end

  def row(basket)
    shop_order = @shop_orders_index[[ basket.membership.member_id, basket.delivery_id ]]

    cols = []

    unless @single_delivery
      cols << basket.delivery.display_number
      cols << basket.delivery.date
    end

    cols << basket.id
    cols << basket.membership_id
    cols << basket.membership.member&.display_id

    if @single_delivery
      member = basket.membership.member
      cols << member.name
      cols << member.emails_array.join(", ")
      cols << member.phones_array.map(&:phony_formatted).join(", ")
      cols << member.street
      cols << member.zip
      cols << member.city
      cols << member.food_note
      cols << member.delivery_note
    end

    cols << basket.depot_id
    cols << basket.depot&.public_name
    cols << cur(basket.depot_price)
    cols << basket.basket_size_id
    cols << basket.basket_size.name
    cols << basket.quantity
    cols << cur(basket.basket_size_price)
    cols << basket.state
    cols << basket.absence_id
    cols << basket.provisionally_absent?
    cols << cur(basket.calculated_price_extra) if feature?("basket_price_extra")
    cols << basket.basket_description(public_name: true)

    if @basket_complements_exist
      complement_columns.each do |c|
        basket_qty = basket.baskets_basket_complements.select { |bc| bc.basket_complement_id == c.id }.sum(&:quantity)
        shop_qty = shop_order&.items&.select { |i| i.product.basket_complement_id == c.id }&.sum(&:quantity) || 0
        cols << (basket_qty + shop_qty)
      end
      cols << basket.complements_description(public_name: true)
      cols << cur(basket.complements_price)
    end

    if feature?("shop")
      cols << (shop_order ? "X" : nil)
      cols << shop_order&.complements_description if @basket_complements_exist
      @shop_products.each do |p|
        quantity = shop_order&.items&.find { |i| i.product_id == p.id }&.quantity
        cols << (quantity ? "#{quantity}x #{p.name_with_single_variant}" : nil)
      end
    end

    cols
  end

  def complement_columns
    @complement_columns ||= BasketComplement.for(baskets, @shop_orders)
  end

  def load_shop_orders
    if feature?("shop")
      Shop::Order.where(delivery: @deliveries).includes(items: { product: :basket_complement })
    else
      Shop::Order.none
    end
  end

  def feature?(name)
    Current.org.feature?(name)
  end

  def cur(number)
    return if number.nil? || number.zero?

    number_to_currency(number, unit: Current.org.currency_code, format: "%n %u", precision: 3)
  end
end
