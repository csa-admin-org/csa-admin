class Depot < ApplicationRecord
  include HasEmails
  include HasPhones
  include HasLanguage
  include TranslatedAttributes
  include TranslatedRichTexts
  include HasVisibility

  attribute :language, :string, default: -> { Current.acp.languages.first }

  translated_attributes :public_name
  translated_rich_texts :public_note

  has_many :baskets
  has_many :memberships
  has_many :members, through: :memberships
  has_and_belongs_to_many :basket_contents
  has_and_belongs_to_many :deliveries_cycles,
    after_add: :deliveries_cycles_changed!,
    after_remove: :deliveries_cycles_changed!
  has_and_belongs_to_many :visibe_deliveries_cycles,
    -> { visible },
    class_name: 'DeliveriesCycle'

  default_scope { order(:name) }
  scope :free, -> { where('price = 0') }
  scope :paid, -> { where('price > 0') }
  scope :used, -> {
    joins(:memberships)
      .merge(Membership.current_or_future)
      .reorder(:id)
      .distinct
    }

  validates :name, :form_priority, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :deliveries_cycles, presence: true

  after_commit :update_baskets_async, on: :update

  def public_name
    self[:public_names][I18n.locale.to_s].presence || name
  end

  def baskets_for(delivery)
    baskets
      .not_absent
      .not_empty
      .includes(:basket_size, :complements, :member, :baskets_basket_complements)
      .where(delivery_id: delivery.id)
      .order('members.name')
      .uniq
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

  def require_delivery_address?
    address.blank?
  end

  def full_address
    return unless [address, zip, city].all?(&:present?)

    [address, "#{zip} #{city}"].compact.join(', ')
  end

  def include_delivery?(delivery)
    deliveries_cycles.any? { |dc| dc.include_delivery?(delivery) }
  end

  def current_and_future_delivery_ids
    @current_and_future_delivery_ids ||=
      deliveries_cycles.map(&:current_and_future_delivery_ids).flatten.uniq
  end

  def visible_deliveries_cycle_ids
    if visibe_deliveries_cycles.none?
      [main_deliveries_cycle.id]
    else
      visibe_deliveries_cycles.pluck(:id)
    end
  end

  def deliveries_counts
    if visibe_deliveries_cycles.none?
      [main_deliveries_cycle.deliveries_count]
    else
      visibe_deliveries_cycles.map(&:deliveries_count).uniq
    end
  end

  def main_deliveries_cycle
    deliveries_cycles.max_by(&:deliveries_count)
  end

  def can_destroy?
    memberships.none? && baskets.none? && basket_contents.none?
  end

  private

  def deliveries_cycles_changed!(deliveries_cycle)
    @deliveries_cycles_changes ||= []
    @deliveries_cycles_changes << deliveries_cycle
  end

  def update_baskets_async
    return unless @deliveries_cycles_changes

    @deliveries_cycles_changes.uniq.each do |deliveries_cycle|
      DeliveriesCycleBasketsUpdaterJob.perform_later(deliveries_cycle)
    end
  end
end
