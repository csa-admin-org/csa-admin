class Depot < ApplicationRecord
  include HasEmails
  include HasPhones
  include HasLanguage
  include TranslatedAttributes
  include TranslatedRichTexts
  include HasVisibility
  include HasDeliveryCycles

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

  attribute :language, :string, default: -> { Current.acp.languages.first }

  translated_attributes :public_name
  translated_rich_texts :public_note

  has_many :baskets
  has_many :memberships
  has_many :members, through: :memberships
  has_and_belongs_to_many :basket_contents

  default_scope { order(:position) }
  scope :member_ordered, -> {
    order_clauses = ['member_order_priority']
    order_clauses <<
      case Current.acp.depots_member_order_mode
      when 'price_asc'; 'price ASC'
      when 'price_desc'; 'price DESC'
      end
    order_clauses << "COALESCE(NULLIF(public_names->>'#{I18n.locale}', ''), name)"
    reorder(Arel.sql(order_clauses.compact.join(', ')))
  }
  scope :free, -> { where('price = 0') }
  scope :paid, -> { where('price > 0') }
  scope :used, -> {
    joins(:memberships)
      .merge(Membership.current_or_future)
      .reorder(:id)
      .distinct
  }

  validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :delivery_sheets_mode, inclusion: { in: DELIVERY_SHEETS_MODES }, presence: :true

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
      .not_absent
      .not_empty
      .includes(:basket_size, :complements, :member, :membership, :baskets_basket_complements)
      .where(delivery_id: delivery.id)
      .uniq
      .sort_by { |basket| member_sorting(basket.member) }
  end

  def member_sorting(member)
    position = []
    if delivery_sheets_mode == 'home_delivery'
      position << (member_ids_position.index(member.id) || 1000)
    end
    position << member.name
    position
  end

  def baskets_count_for(delivery, basket_size)
    baskets
      .not_absent
      .not_empty
      .where(delivery_id: delivery.id, basket_size_id: basket_size.id)
      .count
  end

  def free?
    price.zero?
  end

  def paid?
    price.positive?
  end

  def require_delivery_address?
    address.blank?
  end

  def full_address
    return unless [address, zip, city].all?(&:present?)

    [address, "#{zip} #{city}"].compact.join(', ')
  end

  def can_destroy?
    memberships.none? && baskets.none? && basket_contents.none?
  end
end
