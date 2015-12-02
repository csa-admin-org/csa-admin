class Invoice < ActiveRecord::Base
  belongs_to :member

  # scope :open, -> { where('balance > 0') }
  # scope :closed, -> { where('balance <= 0') }
  scope :during_year, ->(year) {
    where(
      'date >= ? AND date <= ?',
      Date.new(year).beginning_of_year,
      Date.new(year).end_of_year
    )
  }

  before_create :set_amount

  # def status
  #   balance > 0 ? :open : :closed
  # end

  # def display_status
  #   I18n.t("invoice.status.#{status}")
  # end

  private

  def set_amount
    self.amount = (memberships_amount || 0) + (support_amount || 0)
  end
end
