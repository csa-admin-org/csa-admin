# frozen_string_literal: true

class Depot < ApplicationRecord
  MEMBER_ORDER_MODES = %w[
    name_asc
    price_asc
    price_desc
  ]

  DELIVERY_SHEETS_MODES = %w[
    signature
    home_delivery
  ]

  include TranslatedAttributes
  include TranslatedRichTexts
  include HasEmails
  include HasPhones
  include HasLanguage
  include HasPrice
  include HasPublicName
  include HasVisibility
  include Discardable
  include Depot::Geocoding

  acts_as_list

  attribute :language, :string, default: -> { Current.org.languages.first }

  translated_attributes :form_detail
  translated_attributes :invoice_name
  translated_rich_texts :public_note

  has_many :baskets
  has_many :memberships
  has_many :members, through: :memberships
  has_and_belongs_to_many :basket_contents
  has_and_belongs_to_many :delivery_cycles, -> { kept } # Visibility
  belongs_to :group, class_name: "DepotGroup", optional: true

  default_scope { order(:position) }
  scope :for_member_form, ->(object = nil) {
    ids = visible.ids
    ids << object.depot_id if object
    where(id: ids.uniq)
  }
  scope :member_ordered, -> {
    order_clauses = [ "member_order_priority" ]
    order_clauses <<
      case Current.org.depots_member_order_mode
      when "price_asc"; "price ASC"
      when "price_desc"; "price DESC"
      end
    reorder(Arel.sql(order_clauses.compact.join(", "))).order_by_public_name
  }
  scope :used, -> {
    joins(:memberships)
      .merge(Membership.current_or_future)
      .reorder(:id)
      .distinct
  }
  scope :mapped, -> {
    kept.visible.where(maps_visible: true).where.not(latitude: nil).where.not(longitude: nil)
  }

  before_validation :set_default_delivery_cycle, on: :create

  validates :delivery_sheets_mode, inclusion: { in: DELIVERY_SHEETS_MODES }, presence: :true
  validates :delivery_cycles, presence: true
  validates :notify_days_before_delivery, numericality: { greater_than_or_equal_to: 0, only_integer: true }, presence: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90, allow_blank: true }
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180, allow_blank: true }
  validates :latitude, :longitude, presence: true, if: :maps_visible?

  def self.prices?
    kept.pluck(:price).any?(&:positive?)
  end

  def move_to(position, delivery)
    # Take over position within delivery context
    position = delivery.used_depots[position - 1].position
    insert_at(position)
  end

  def move_member_to(position, member, delivery)
    member_ids = baskets_for(delivery).map { |b| b.member.id }
    member_ids_position = member_ids_position_for(delivery)
    position = member_ids_position.index(member_ids[position - 1])
    update_column(
      :member_ids_position,
      member_ids_position.insert(position, member_ids_position.delete(member.id)))
  end

  def member_ids_position_for(delivery)
    member_ids = baskets_for(delivery).map { |b| b.member.id }
    member_ids_position.map { |member_id|
      member_ids.delete(member_id) || member_id
    } + member_ids
  end

  def baskets_for(delivery)
    list = baskets
      .deliverable
      .includes(:basket_size, :complements, :member, :membership, :baskets_basket_complements)
      .where(delivery_id: delivery.id)
      .uniq
    indexes = basket_size_indexes_for_sorting
    list.sort_by { |basket|
      index = indexes ? indexes.fetch(basket.basket_size_id, indexes.size) : nil
      member_sorting(basket.member, basket_size_index: index)
    }
  end

  def sort_delivery_sheet_members(members, baskets)
    indexes = basket_size_indexes_for_sorting
    return members.sort_by { |member| member_sorting(member) } unless indexes

    index_by_member_id = earliest_basket_size_indexes(baskets, indexes)
    last = indexes.size
    members.sort_by { |member|
      member_sorting(member, basket_size_index: index_by_member_id.fetch(member.id, last))
    }
  end

  def member_sorting(member, basket_size_index: nil)
    position = []
    if delivery_sheets_mode == "home_delivery"
      position << (member_ids_position.index(member.id) || 1000)
    elsif !basket_size_index.nil?
      position << basket_size_index
    end
    position << I18n.transliterate(member.name).downcase
    position
  end

  def baskets_count_for(delivery, basket_size)
    baskets
      .deliverable
      .where(delivery_id: delivery.id, basket_size_id: basket_size.id)
      .count
  end

  def invoice_description
    if invoice_name?
      invoice_name
    else
      [ Depot.model_name.human, public_name ].join(": ")
    end
  end

  def full_address
    return unless [ street, zip, city ].all?(&:present?)

    [ street, "#{zip} #{city}" ].compact.join(", ")
  end

  def can_delete?
    memberships.none? && baskets.none? && basket_contents.none?
  end

  def can_discard?
    memberships.current_and_future_year.none? && baskets.current_and_future_year.none?
  end

  def include_delivery?(delivery)
    delivery_cycles.any? { |dc| dc.include_delivery?(delivery) }
  end

  def billable_deliveries_counts
    if DeliveryCycle.visible?
      delivery_cycles.map(&:billable_deliveries_count).uniq.sort
    else
      DeliveryCycle.billable_deliveries_counts
    end
  end

  def future_deliveries_counts
    if DeliveryCycle.visible?
      delivery_cycles.map(&:future_deliveries_count).uniq.sort
    else
      DeliveryCycle.future_deliveries_counts
    end
  end

  def next_delivery
    baskets.coming.first&.delivery
  end

  private

  def set_default_delivery_cycle
    self.delivery_cycles << DeliveryCycle.primary if delivery_cycles.empty?
  end

  def basket_size_indexes_for_sorting
    return if delivery_sheets_mode == "home_delivery"
    return unless Current.org.delivery_pdf_member_order_mode == "basket_size"

    BasketSize.ordered.ids.each_with_index.to_h
  end

  def earliest_basket_size_indexes(baskets, indexes)
    pairs = baskets.filled.pluck(:membership_id, :basket_size_id)
    member_id_by_membership_id =
      Membership.where(id: pairs.map(&:first)).pluck(:id, :member_id).to_h
    chosen = {}
    pairs.each do |membership_id, size_id|
      member_id = member_id_by_membership_id[membership_id]
      next unless member_id

      index = indexes.fetch(size_id, indexes.size)
      current = chosen[member_id]
      chosen[member_id] = index if current.nil? || index < current
    end
    chosen
  end
end
