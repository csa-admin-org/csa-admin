class Member < ActiveRecord::Base
  BILLING_INERVALS = %w[annual quarterly].freeze

  uniquify :token, length: 10

  belongs_to :validator, class_name: 'Admin'
  belongs_to :waiting_basket, class_name: 'Basket'
  belongs_to :waiting_distribution, class_name: 'Distribution'
  has_many :halfday_works
  has_many :memberships
  has_many :billing_memberships, class_name: 'Membership', foreign_key: 'billing_member_id'
  has_one :current_membership, -> { current }, class_name: 'Membership'

  accepts_nested_attributes_for :memberships

  scope :pending, -> { where(validated_at: nil) }
  scope :validated, -> { where.not(validated_at: nil) }
  scope :waiting, -> { validated.where.not(waiting_started_at: nil) }
  scope :not_waiting, -> { validated.where(waiting_started_at: nil) }
  scope :with_current_membership, -> { not_waiting.joins(:current_membership) }
  scope :without_current_membership,
    -> { where.not(id: Member.with_current_membership.pluck(:id)) }
  scope :valid_for_memberships,
    -> { validated.not_waiting.where(support_member: false) }
  scope :trial, -> {
    with_current_membership.
      where('members.created_at >= ?', Time.utc(2014,11)).
      where('(SELECT COUNT(deliveries.id) FROM deliveries WHERE date >= (SELECT m.started_on FROM memberships m WHERE m.member_id = members.id ORDER BY m.started_on LIMIT 1) AND date <= ?) <= 4', Date.today)
  }
  scope :active, -> {
    with_current_membership.
      where('members.created_at < ? OR (SELECT COUNT(deliveries.id) FROM deliveries WHERE date >= (SELECT m.started_on FROM memberships m WHERE m.member_id = members.id ORDER BY m.started_on LIMIT 1) AND date <= ?) > 4', Time.utc(2014,11), Date.today)
  }
  scope :support, -> {
    not_waiting
      .without_current_membership
      .where(support_member: true)
  }
  scope :inactive, -> {
    not_waiting
      .without_current_membership
      .where(support_member: false)
  }
  scope :with_name, ->(name) {
    where('first_name ILIKE :name OR last_name ILIKE :name', name: "%#{name}%")
  }
  scope :with_address, ->(address) {
    where('members.address ILIKE ?', "%#{address}%")
  }
  scope :with_current_basket, ->(basket_id) {
    member_ids = Membership.where(basket_id: basket_id).pluck(:member_id)
    where('members.id IN (?) OR waiting_basket_id = ?', member_ids, basket_id)
  }
  scope :with_current_distribution, ->(distribution_id) {
    member_ids = Membership.where(distribution_id: distribution_id).pluck(:member_id)
    where('members.id IN (?) OR waiting_distribution_id = ?', member_ids, distribution_id)
  }

  validates :billing_interval,
    presence: true,
    inclusion: { in: BILLING_INERVALS }
  validates :first_name, :last_name, presence: true
  validates :emails, presence: true,
    if: ->(member) { member.read_attribute(:gribouille) }
  validates :address, :city, :zip, presence: true,
    if: ->(member) {
      member.status.in?(%i[trial active support]) ||
        (member.status == :inactive && member.gribouille == false)
    }
  validates :waiting_basket, :waiting_distribution, presence: true,
    if: ->(member) {
      member.waiting_started_at_changed? && member.waiting_started_at.nil?
    }
  validate :support_member_not_waiting
  validate :support_member_without_current_membership

  before_save :build_membership

  def self.gribouille_emails
    all.includes(:current_membership).select(&:gribouille?)
      .map(&:emails_array).flatten.uniq.compact
  end

  def name
    "#{first_name} #{last_name}"
  end

  def display_address
    "#{address}, #{city} (#{zip})"
  end

  def display_delivery_address
    "#{delivery_address}, #{delivery_city} (#{delivery_zip})"
  end

  def same_delivery_address?
    display_address == display_delivery_address
  end

  def delivery_address
    read_attribute(:delivery_address) || address
  end

  def delivery_city
    read_attribute(:delivery_city) || city
  end

  def delivery_zip
    read_attribute(:delivery_zip) || zip
  end

  def basket
    current_membership.try(:basket) || waiting_basket
  end

  def distribution
    current_membership.try(:distribution) || waiting_distribution
  end

  def self.ransackable_scopes(auth_object = nil)
    %i[with_name with_address with_current_basket with_current_distribution]
  end

  def status
    if pending?
      :pending
    elsif waiting?
      :waiting
    elsif current_membership
      trial? ? :trial : :active
    elsif support?
      :support
    else
      :inactive
    end
  end

  def display_status
    I18n.t("member.status.#{status}")
  end

  def support_member=(bool)
    self.billing_interval = 'annual' if bool || bool == '1'
    write_attribute(:support_member, bool)
  end

  def waiting=(bool)
    self.waiting_started_at = (bool == '1') ? Time.now : nil
  end

  def validate!(validator)
    return unless status == :pending
    update!(
      waiting_started_at: Time.now,
      validated_at: Time.now,
      validator: validator
    )
  end

  def gribouille?
    (status.in?(%i[waiting trial active support]) &&
      read_attribute(:gribouille) != false) ||
      read_attribute(:gribouille) == true
  end

  def emails_array
    string_to_a(emails)
  end

  def phones_array
    string_to_a(phones)
  end

  def remaining_halfday_works_count
    [2 - halfday_works.past.validated.to_a.sum(&:value), 0].max
  end

  def to_param
    token
  end

  def can_destroy?
    status.in? %i[pending waiting]
  end

  def pending?
    !validated_at?
  end

  def waiting
    waiting_started_at?
  end
  alias_method :waiting?, :waiting

  def support?
    support_member?
  end

  def trial?
    created_at >= Time.utc(2014, 11) && # TODO: remove once 4 deliveries are done.
      current_membership &&
      deliveries_received_count_since_first_membership <= 4
  end

  def deliveries_received_count_since_first_membership
    first_membership_started_on = memberships.pluck(:started_on).sort.first
    Delivery.between(first_membership_started_on..Date.today).count
  end

  def billable?
    status == :active
  end

  private

  def build_membership
    if (new_record? || waiting_started_at_changed?) &&
       waiting_started_at.nil? && waiting_basket_id? && waiting_distribution_id?
      memberships.build(
        basket_id: waiting_basket_id,
        distribution_id: waiting_distribution_id,
        member: self,
        started_on: Date.today,
        ended_on: Date.today.end_of_year
      )
    end
  end

  def string_to_a(str)
    str.to_s.split(',').each(&:strip!)
  end

  def support_member_not_waiting
    if support_member && status == :waiting
      errors.add(:support_member, "ne peut pas être sur liste d'attente")
    end
  end

  def support_member_without_current_membership
    if support_member && memberships.any?(&:current?)
      errors.add(:support_member, 'invalide avec un abonnement')
    end
  end
end
