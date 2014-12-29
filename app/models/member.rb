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

  scope :waiting_validation, -> { where(validated_at: nil) }
  scope :validated, -> { where.not(validated_at: nil) }
  scope :waiting_list, -> { validated.where.not(waiting_from: nil) }
  scope :not_waiting, -> { validated.where(waiting_from: nil) }
  scope :with_current_membership, -> { joins(:current_membership) }
  scope :without_current_membership,
    -> { where.not(id: Member.with_current_membership.pluck(:id)) }
  scope :valid_for_memberships, -> {
    validated.not_waiting.where(support_member: false)
  }
  scope :active, -> { not_waiting.with_current_membership }
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
    if: ->(member) { member.status.in?(%i[active support]) || (member.status == :inactive && !member.gribouille) }
  validates :waiting_basket, :waiting_distribution, presence: true,
    if: ->(member) { member.waiting_from_changed? && member.waiting_from.nil? }
  validate :support_member_not_waiting
  validate :support_member_without_current_membership

  before_save :build_membership

  def self.gribouille_emails
    all.includes(:current_membership).select(&:gribouille).map(&:emails_array).flatten.uniq.compact
  end

  def name
    "#{first_name} #{last_name}"
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
    if !validated_at?
      :waiting_validation
    elsif waiting_from?
      :waiting_list
    elsif current_membership
      :active
    elsif support_member?
      :support
    else
      :inactive
    end
  end

  def support_member=(bool)
    self.billing_interval = 'annual' if bool || bool == '1'
    write_attribute(:support_member, bool)
  end

  def waiting_list=(bool)
    self.waiting_from = bool == '1' ? Time.now : nil
  end

  def validate!(validator)
    return unless status == :waiting_validation
    update!(
      waiting_from: Time.now,
      validated_at: Time.now,
      validator: validator
    )
  end

  def gribouille=(bool)
    write_attribute(:gribouille, bool) unless status == :active
  end

  def gribouille
    status == :active || read_attribute(:gribouille)
  end
  alias_method :gribouille?, :gribouille

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

  def waiting_list
    waiting_from?
  end
  alias_method :waiting_list?, :waiting_list

  def can_destroy?
    status.in? %i[waiting_validation waiting_list]
  end

  private

  def build_membership
    if (new_record? || waiting_from_changed?) &&
        waiting_from.nil? && waiting_basket_id? && waiting_distribution_id?
      self.memberships.build(
        basket_id: waiting_basket_id,
        distribution_id: waiting_distribution_id,
        member: self,
        started_on: Date.today_2015,
        ended_on: Date.today_2015.end_of_year
      )
    end
  end

  def string_to_a(str)
    str.to_s.split(',').each(&:strip!)
  end

  def support_member_not_waiting
    if support_member && status == :waiting_list
      errors.add(:support_member, "ne peut pas être sur liste d'attente")
    end
  end

  def support_member_without_current_membership
    if support_member && memberships.any?(&:current?)
      errors.add(:support_member, 'invalide avec un abonnement')
    end
  end
end
