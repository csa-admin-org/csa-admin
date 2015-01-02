class Distribution < ActiveRecord::Base
  attr_accessor :delivery_memberships

  has_many :memberships
  has_many :members, through: :memberships

  default_scope { order(:name) }

  validates :name, presence: true

  def require_delivery_address?
    address.blank?
  end


  def self.with_delivery_memberships(delivery)
    joins(:memberships).merge(Membership.including_date(delivery.date))
      .distinct
      .each { |d| d.delivery_memberships = d.memberships.including_date(delivery.date).includes(:member) }
      .sort_by { |d| d.delivery_memberships.size }.reverse
  end
end
