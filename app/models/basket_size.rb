class BasketSize < ApplicationRecord
  include TranslatedAttributes
  include HasVisibility

  translated_attributes :name, required: true
  translated_attributes :public_name
  translated_attributes :form_detail

  has_many :memberships
  has_many :members, through: :memberships
  has_many :baskets, through: :memberships

  default_scope { order(:price) }
  scope :free, -> { where('price = 0') }
  scope :paid, -> { where('price > 0') }
  scope :used, -> {
    ids = Basket
      .joins(:delivery)
      .merge(Delivery.current_and_future_year)
      .pluck(:basket_size_id)
      .uniq
    where(id: ids)
  }

  validates :form_priority, presence: true
  validates :price,
    numericality: { greater_than_or_equal_to: 0 },
    presence: true
  validates :activity_participations_demanded_annualy,
    numericality: { greater_than_or_equal_to: 0 },
    presence: true
  validates :acp_shares_number,
    numericality: { greater_than_or_equal_to: 1 },
    allow_nil: true

  def display_name; name end

  def public_name
    self[:public_names][I18n.locale.to_s].presence || name
  end

  def can_destroy?
    memberships.none? && baskets.none?
  end

  def price_for(year)
    Basket
      .during_year(year)
      .where(basket_size: self)
      .pluck(:basket_price)
      .group_by(&:itself)
      .max_by(&:size)
      &.first || 0
  end
end
