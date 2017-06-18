class Member < ActiveRecord::Base
  BILLING_INTERVALS = %w[annual quarterly].freeze
  SUPPORT_PRICE = 30
  TRIAL_DELIVERIES = 4

  acts_as_paranoid
  uniquify :token, length: 10

  belongs_to :validator, class_name: 'Admin'
  belongs_to :waiting_basket, class_name: 'Basket'
  belongs_to :waiting_distribution, class_name: 'Distribution'
  has_many :absences
  has_many :invoices
  has_many :old_invoices
  has_many :current_year_invoices, -> { during_year(Time.zone.today.year) },
    class_name: 'Invoice'
  has_many :halfday_participations
  has_many :memberships
  has_many :current_year_memberships, -> { during_year(Time.zone.today.year) },
    class_name: 'Membership'
  has_one :first_membership, -> { order(:started_on) }, class_name: 'Membership'
  has_one :current_membership, -> { current }, class_name: 'Membership'
  has_one :future_membership,
    -> { future_current_year },
    class_name: 'Membership'

  accepts_nested_attributes_for :memberships

  scope :pending, -> { where(validated_at: nil) }
  scope :validated, -> { where.not(validated_at: nil) }
  scope :waiting, -> { validated.where.not(waiting_started_at: nil) }
  scope :not_waiting, -> { validated.where(waiting_started_at: nil) }
  scope :with_current_membership, -> { not_waiting.joins(:current_membership) }
  scope :without_current_membership,
    -> { where.not(id: Member.with_current_membership.pluck(:id)) }
  scope :valid_for_memberships, -> { validated.not_waiting }
  DELIVERIES_COUNT = %{(
    SELECT COUNT(deliveries.id)
    FROM deliveries
    WHERE
      date >= (
        SELECT m.started_on
        FROM memberships m
        WHERE m.member_id = members.id
        ORDER BY m.started_on
        LIMIT 1
      ) AND
      date <= current_date
  )}
  scope :trial, -> {
    with_current_membership.where("#{DELIVERIES_COUNT} <= #{TRIAL_DELIVERIES}")
  }
  scope :active, -> {
    with_current_membership.where("#{DELIVERIES_COUNT} > #{TRIAL_DELIVERIES}")
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
  scope :mailable, -> { where.not(emails: nil) }
  scope :with_address, ->(address) {
    where('members.address ILIKE ?', "%#{address}%")
  }
  scope :with_current_basket, ->(basket_id) {
    ids = Membership.where(basket_id: basket_id).pluck(:member_id)
    where('members.id IN (?) OR waiting_basket_id = ?', ids, basket_id)
  }
  scope :with_current_distribution, ->(distribution_id) {
    ids = Membership.where(distribution_id: distribution_id).pluck(:member_id)
    where('members.id IN (?) OR waiting_distribution_id = ?',
      ids, distribution_id)
  }
  scope :paid_basket, -> { where(salary_basket: false) }
  scope :renew_membership, -> { where(renew_membership: true) }

  validates :billing_interval,
    presence: true,
    inclusion: { in: BILLING_INTERVALS }
  validates :first_name, :last_name, presence: true
  validates :emails, presence: true,
    if: ->(member) { member.read_attribute(:gribouille) }
  validates :address, :city, :zip, presence: true,
    if: ->(member) {
      member.status.in?(%i[trial active support]) ||
        (member.status == :inactive && member.gribouille == false)
    }
  validate :support_member_not_waiting

  before_save :build_membership

  def self.gribouille
    all.includes(:current_membership, :future_membership).select(&:gribouille?)
  end

  def self.gribouille_emails
    gribouille.map(&:emails_array).flatten.uniq.compact
  end

  def self.with_current_membership_emails
    all.with_current_membership.map(&:emails_array).flatten.uniq.compact
  end

  def self.billable
    includes = %i[
      current_year_memberships
      current_year_invoices
      memberships
      first_membership
      current_membership
    ]
    Member.includes(*includes).all.select(&:billable?)
  end

  def name
    "#{last_name} #{first_name}".strip
  end

  def display_address
    "#{address}, #{city} (#{zip})"
  end

  def display_delivery_address
    "#{final_delivery_address}, #{final_delivery_city} (#{final_delivery_zip})"
  end

  def same_delivery_address?
    display_address == display_delivery_address
  end

  def final_delivery_address
    read_attribute(:delivery_address).presence || address
  end

  def final_delivery_city
    read_attribute(:delivery_city).presence || city
  end

  def final_delivery_zip
    read_attribute(:delivery_zip).presence || zip
  end

  def basket
    current_membership.try(:basket) ||
      waiting_basket ||
      future_membership.try(:basket)
  end

  def distribution
    current_membership.try(:distribution) ||
      waiting_distribution ||
      future_membership.try(:distribution)
  end

  def self.ransackable_scopes(_auth_object = nil)
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

  def active?
    status == :active
  end

  def display_status
    I18n.t("member.status.#{status}")
  end

  def support_member=(bool)
    if bool || bool == '1'
      self.billing_interval = 'annual'
      self.waiting_started_at = nil
      self.waiting_basket_id = nil
      self.waiting_distribution_id = nil
    end
    write_attribute(:support_member, bool)
  end

  def waiting=(bool)
    self.waiting_started_at = (bool == '1') ? Time.zone.now : nil
  end

  def validate!(validator)
    return unless status == :pending
    now = Time.zone.now
    update!(
      waiting_started_at: support? ? nil : now,
      validated_at: now,
      validator: validator
    )
  end

  def wait!
    return unless status == :inactive
    update!(
      waiting_started_at: Time.zone.now,
      waiting_basket_id: nil,
      waiting_distribution_id: nil
    )
  end

  def gribouille?
    gribouille = read_attribute(:gribouille)
    gribouille == true || (
      (waiting? || current_membership || future_membership || support?) &&
      gribouille != false
    )
  end

  def absent?(date)
    absences.any? { |absence| absence.period.include?(date) }
  end

  def emails_array
    string_to_a(emails)
  end

  def emails?
    emails_array.present?
  end

  def phones_array
    string_to_a(phones)
  end

  def annual_halfday_works(year = nil)
    @annual_halfday_works ||= begin
      if salary_basket?
        0
      else
        year ||= Time.zone.today.year
        memberships.during_year(year).to_a.sum(&:halfday_works)
      end
    end
  end

  def validated_halfday_works(year = nil)
    @validated_halfday_works ||= begin
      year ||= Time.zone.today.year
      halfday_participations.during_year(year).validated.to_a.sum(&:value)
    end
  end

  def remaining_halfday_works(year = nil)
    [annual_halfday_works(year) - validated_halfday_works(year), 0].max
  end

  def extra_halfday_works(year = nil)
    [annual_halfday_works(year) - validated_halfday_works(year), 0].min.abs
  end

  def skipped_halfday_works(year = nil)
    if salary_basket?
      0
    else
      [memberships.during_year(year).to_a.sum(&:normal_halfday_works) - validated_halfday_works(year), 0].max
    end
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
    first_membership && first_membership.year == Date.current.year &&
      deliveries_received_count_since_first_membership <= TRIAL_DELIVERIES
  end

  def deliveries_received_count_since_first_membership
    current_year_memberships.sum { |m| m.deliveries_received_count }
  end

  def billable?
    support? ||
      (!salary_basket? && current_year_memberships.present? && !trial?) ||
      (trial? && !current_membership)
  end

  def support_billable?
    billable? &&
      (support? ||
        (active? && memberships.to_a.sum(&:deliveries_received_count) > 4))
  end

  private

  def build_membership
    if !pending? && (new_record? || waiting_started_at_changed?) &&
        waiting_started_at.nil? &&
        waiting_basket_id? && waiting_distribution_id?
      basket_date = Date.new(waiting_basket.year)
      memberships.build(
        basket_id: waiting_basket_id,
        distribution_id: waiting_distribution_id,
        member: self,
        started_on: [Time.zone.today, basket_date.beginning_of_year].max,
        ended_on: basket_date.end_of_year
      )
      self.waiting_basket_id = nil
      self.waiting_distribution_id = nil
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
end
