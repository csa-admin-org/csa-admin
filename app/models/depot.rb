# frozen_string_literal: true

class Depot < ApplicationRecord
  include HasEmails
  include HasPhones
  include HasLanguage
  include HasPrice
  include TranslatedAttributes
  include TranslatedRichTexts
  include HasVisibility
  include Discardable

  MEMBER_ORDER_MODES = %w[
    name_asc
    price_asc
    price_desc
  ]

  DELIVERY_SHEETS_MODES = %w[
    signature
    home_delivery
  ]

  acts_as_list

  attribute :language, :string, default: -> { Current.org.languages.first }

  translated_attributes :public_name
  translated_rich_texts :public_note

  has_many :baskets
  has_many :memberships
  has_many :members, through: :memberships
  has_and_belongs_to_many :basket_contents
  has_and_belongs_to_many :delivery_cycles, -> { kept } # Visibility
  belongs_to :group, class_name: "DepotGroup", optional: true

  default_scope { order(:position) }
  scope :member_ordered, -> {
    order_clauses = [ "member_order_priority" ]
    order_clauses <<
      case Current.org.depots_member_order_mode
      when "price_asc"; "price ASC"
      when "price_desc"; "price DESC"
      end
    order_clauses << "COALESCE(NULLIF(json_extract(public_names, '$.#{I18n.locale}'), ''), name)"
    reorder(Arel.sql(order_clauses.compact.join(", ")))
  }
  scope :used, -> {
    joins(:memberships)
      .merge(Membership.current_or_future)
      .reorder(:id)
      .distinct
  }

  before_validation :set_default_delivery_cycle, on: :create

  validates :delivery_sheets_mode, inclusion: { in: DELIVERY_SHEETS_MODES }, presence: :true
  validates :delivery_cycles, presence: true

  def display_name; name end

  def public_name
    self[:public_names][I18n.locale.to_s].presence || name
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
    baskets
      .deliverable
      .includes(:basket_size, :complements, :member, :membership, :baskets_basket_complements)
      .where(delivery_id: delivery.id)
      .uniq
      .sort_by { |basket| member_sorting(basket.member) }
  end

  def member_sorting(member)
    position = []
    if delivery_sheets_mode == "home_delivery"
      position << (member_ids_position.index(member.id) || 1000)
    end
    position << member.name
    position
  end

  def baskets_count_for(delivery, basket_size)
    baskets
      .deliverable
      .where(delivery_id: delivery.id, basket_size_id: basket_size.id)
      .count
  end

  def require_delivery_address?
    address.blank?
  end

  def full_address
    return unless [ address, zip, city ].all?(&:present?)

    [ address, "#{zip} #{city}" ].compact.join(", ")
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
    self.delivery_cycles << DeliveryCycle.greatest if delivery_cycles.empty?
  end
end
