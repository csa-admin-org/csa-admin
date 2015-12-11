class Invoice < ActiveRecord::Base
  attr_accessor :memberships_amount_fraction

  belongs_to :member

  scope :current_year, -> { during_year(Time.zone.today.year) }
  scope :during_year, ->(year) {
    date = Date.new(year)
    where('date >= ? AND date <= ?', date.beginning_of_year, date.end_of_year)
  }
  scope :quarter, ->(n) { where('EXTRACT(QUARTER FROM date) = ?', n) }
  scope :support, -> { where.not(support_amount: nil) }
  scope :membership, -> { where.not(memberships_amount: nil) }

  before_validation \
    :set_paid_memberships_amount,
    :set_remaining_memberships_amount,
    :set_memberships_amount,
    :set_amount

  validate :validate_memberships_amounts_data
  validates :member, presence: true
  validates :date, presence: true, uniqueness: { scope: :member_id }
  validates :memberships_amount_fraction, inclusion: { in: [1, 2, 3, 4] }
  validates :paid_memberships_amount,
    numericality: { greater_than_or_equal_to: 0 },
    allow_nil: true
  validates :memberships_amount,
    numericality: { greater_than: 0 },
    allow_nil: true
  validates :memberships_amounts_data,
    presence: true,
    unless: -> { support_amount? }
  validates :memberships_amount_description,
    presence: true,
    if: -> { memberships_amount? }
  validate :validate_memberships_amount_for_current_year

  def memberships_amount_fraction
    @memberships_amount_fraction || 1 # bill for everything by default
  end

  def amount=(_)
    raise 'is set automaticaly.'
  end

  def memberships_amount=(_)
    raise 'is set automaticaly.'
  end

  def remaining_memberships_amount=(_)
    raise 'is set automaticaly.'
  end

  def memberships_amounts
    (memberships_amounts_data || []).sum { |m| m.symbolize_keys[:amount] }
  end

  def memberships_amounts_data=(data)
    self[:memberships_amounts_data] = data && data.each do |hash|
      hash[:amount] = up_to_five_cent(hash[:amount]) if hash[:amount]
    end
  end

  private

  def validate_memberships_amount_for_current_year
    return unless memberships_amounts_data?
    paid_invoices = member.invoices.membership.during_year(date.year)
    if paid_invoices.sum(:memberships_amount) + memberships_amount >
        memberships_amounts
      errors.add(:base, 'Somme de la facturation des abonnements trop grande')
    end
  end

  def validate_memberships_amounts_data
    if memberships_amounts_data && memberships_amounts_data.any? { |h|
      h.keys.map(&:to_s).sort != %w[amount description id]
    }
      errors.add(:memberships_amounts_data)
    end
  end

  def set_paid_memberships_amount
    return unless memberships_amounts_data?
    paid_invoices = member.invoices.membership.during_year(date.year)
    self[:paid_memberships_amount] ||= paid_invoices.sum(:memberships_amount)
  end

  def set_remaining_memberships_amount
    return unless memberships_amounts_data?
    self[:remaining_memberships_amount] ||=
      memberships_amounts - paid_memberships_amount
  end

  def set_memberships_amount
    return unless memberships_amounts_data?
    amount = remaining_memberships_amount / memberships_amount_fraction.to_f
    self[:memberships_amount] ||= up_to_five_cent(amount)
  end

  def set_amount
    self[:amount] = memberships_amount.to_f + support_amount.to_f
  end

  def up_to_five_cent(amount)
    ((amount.round(2) * 20).round / 20.0)
  end
end
