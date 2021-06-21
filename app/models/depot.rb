class Depot < ActiveRecord::Base
  include HasEmails
  include HasPhones
  include HasLanguage
  include HasDeliveries
  include TranslatedAttributes
  include HasVisibility

  attr_accessor :delivery_memberships

  translated_attributes :form_name

  belongs_to :responsible_member, class_name: 'Member', optional: true
  has_many :baskets
  has_many :memberships
  has_many :members, through: :memberships
  has_and_belongs_to_many :basket_contents

  default_scope { order(:name) }
  scope :free, -> { where('price = 0') }
  scope :paid, -> { where('price > 0') }
  scope :used, -> {
    joins(:memberships)
      .merge(Membership.current_year)
      .reorder(:id)
      .distinct
    }

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true

  def baskets_for(delivery)
    baskets
      .not_absent
      .not_empty
      .includes(:basket_size, :complements, :member, :baskets_basket_complements)
      .where(delivery_id: delivery.id)
      .order('members.name')
      .uniq
  end

  def free?
    price.zero?
  end

  def names
    Current.acp.languages.map { |l|
      [l, self[:form_names][l].presence || name]
    }.to_h
  end

  def require_delivery_address?
    address.blank?
  end

  def full_address
    return unless [address, zip, city].all?(&:present?)

    [address, "#{zip} #{city}"].compact.join(', ')
  end

  def annual_price
    (price * deliveries_count).round_to_five_cents
  end

  def xlsx_worksheet_style
    if Current.acp.ragedevert? && id == 2 # Neuchatel Velo
      :bike_delivery
    else
      :default
    end
  end

  def can_destroy?
    memberships.none? && baskets.none?
  end

  private

  def after_add_delivery!(delivery)
    delivery.add_baskets_at!(self)
  end

  def after_remove_delivery!(delivery)
    delivery.remove_baskets_at!(self)
  end
end
