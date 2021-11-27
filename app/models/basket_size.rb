class BasketSize < ActiveRecord::Base
  include TranslatedAttributes
  include HasVisibility

  translated_attributes :name

  has_many :memberships
  has_many :members, through: :memberships
  has_many :baskets, through: :memberships

  default_scope { order(:price) }
  scope :free, -> { where('price = 0') }
  scope :paid, -> { where('price > 0') }

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

  def can_destroy?
    memberships.none? && baskets.none?
  end
end
