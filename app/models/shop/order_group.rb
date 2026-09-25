# frozen_string_literal: true

module Shop
  class OrderGroup < ApplicationRecord
    self.table_name = "shop_order_groups"

    belongs_to :member, optional: false
    has_many :orders,
      class_name: "Shop::Order",
      foreign_key: :order_group_id,
      inverse_of: :order_group,
      dependent: :nullify
    has_many :invoices, as: :entity, dependent: :destroy
    has_one :invoice, -> { not_canceled }, as: :entity

    validates :period, presence: true

    def self.invoice_orders!(orders, send_email: true)
      orders = Array(orders).select(&:pending?)
      return if orders.empty?

      member = orders.first.member
      key = orders.first.invoice_period_key
      unless orders.all? { |order| order.member_id == member.id && order.invoice_period_key == key }
        raise ArgumentError, "orders must share a member and a billing period"
      end

      transaction do
        group = create!(member: member, period: key)
        orders.each do |order|
          order.update_columns(
            order_group_id: group.id,
            state: Order::INVOICED_STATE,
            updated_at: Time.current)
        end
        group.create_invoice!(send_email: send_email)
        group
      end
    end

    def self.invoice_due!(send_email: true)
      pending = Order.pending
        .with_invoice_period
        .preload(:member, :delivery, items: [ :product, :product_variant ])

      pending.group_by { |order| [ order.member_id, order.invoice_period_key ] }.each_value do |orders|
        next unless orders.all?(&:group_invoice_due?)

        invoice_orders!(orders, send_email: send_email)
      end
    end

    def cancel!
      transaction do
        invoice&.destroy_or_cancel!
        orders.each do |order|
          order.update_columns(
            order_group_id: nil,
            state: Order::PENDING_STATE,
            updated_at: Time.current)
        end
      end
    end

    def can_cancel?
      invoice&.can_destroy_or_cancel?
    end

    def display_period
      [ Order.model_name.human(count: 2), period_label ].join(" ")
    end

    # Mail clause, with the article. PDF header uses period_label.
    def period_phrase
      case period
      when /\A(\d{4})-(\d{2})\z/
        month_period_phrase(Date.new($1.to_i, $2.to_i, 1))
      when /\A(\d{4})-Q([1-4])\z/
        I18n.t("shop.group_invoice.period_phrase.quarter",
          year: $1,
          ordinal: quarter_ordinal($2.to_i))
      when /\A(\d{4})\z/
        I18n.t("shop.group_invoice.period_phrase.year", year: period)
      else
        period
      end
    end

    def create_invoice!(send_email: true)
      I18n.with_locale(member.language) do
        invoices.create!(
          send_email: send_email,
          member: member,
          date: Date.current,
          items_attributes: invoice_items_attributes)
      end
    end

    private

    def period_label
      case period
      when /\A(\d{4})-(\d{2})\z/
        I18n.l(Date.new($1.to_i, $2.to_i, 1), format: :month_year).upcase_first
      when /\A(\d{4})-Q([1-4])\z/
        quarter = $2.to_i
        I18n.t("shop.group_invoice.period.quarter",
          year: $1,
          ordinal: quarter_ordinal(quarter))
      else
        period
      end
    end

    def month_period_phrase(date)
      month = I18n.l(date, format: "%B")
      key = french_month_elision?(month) ? "month_elided" : "month"
      I18n.t("shop.group_invoice.period_phrase.#{key}", month: month, year: date.year)
    end

    def french_month_elision?(month)
      I18n.locale.to_s == "fr" && month.match?(/\A(?:avril|août|octobre)\z/i)
    end

    def quarter_ordinal(quarter)
      case I18n.locale.to_s
      when "fr"
        quarter == 1 ? "1er" : "#{quarter}e"
      when "en"
        { 1 => "1st", 2 => "2nd", 3 => "3rd", 4 => "4th" }.fetch(quarter)
      else
        quarter.to_s
      end
    end

    def invoice_items_attributes
      index = 0
      orders.sort_by { |order| [ order.delivery_date, order.id ] }.each_with_object({}) do |order, attrs|
        attrs[index.to_s] = {
          description: order.invoice_section_description,
          amount: 0
        }
        index += 1

        order.items.each do |item|
          attrs[index.to_s] = {
            description: item.description,
            amount: item.amount
          }
          index += 1
        end

        next unless order.amount_percentage?

        attrs[index.to_s] = {
          description: order.invoice_percentage_description,
          amount: order.invoice_percentage_delta
        }
        index += 1
      end
    end
  end
end
