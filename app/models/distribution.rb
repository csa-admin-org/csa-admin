class Distribution < ActiveRecord::Base
  attr_accessor :delivery_memberships

  has_many :memberships
  has_many :members, through: :memberships
  has_and_belongs_to_many :basket_contents

  default_scope { order(:name) }

  validates :name, presence: true

  def require_delivery_address?
    address.blank?
  end

  def emails_array
    emails.to_s.split(',').each(&:strip!)
  end

  def memberships_for(delivery)
    memberships
      .including_date(delivery.date).includes(:basket, member: :absences).to_a
      .reject { |m| m.member.absent?(delivery.date) }
  end

  def self.with_delivery_memberships(delivery)
    joins(:memberships)
      .merge(Membership.including_date(delivery.date))
      .distinct
      .each { |d| d.delivery_memberships = d.memberships_for(delivery) }
      .sort_by { |d| d.delivery_memberships.size }.reverse
  end
end
