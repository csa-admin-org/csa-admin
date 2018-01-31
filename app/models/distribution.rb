class Distribution < ActiveRecord::Base
  attr_accessor :delivery_memberships

  belongs_to :responsible_member, class_name: 'Member', optional: true
  has_many :baskets
  has_many :memberships
  has_many :members, through: :memberships
  has_and_belongs_to_many :basket_contents

  default_scope { order(:name) }
  scope :free, -> { where('price = 0') }
  scope :paid, -> { where('price > 0') }

  validates :name, presence: true

  def require_delivery_address?
    address.blank?
  end

  def emails_array
    emails.to_s.split(',').each(&:strip!)
  end
end
