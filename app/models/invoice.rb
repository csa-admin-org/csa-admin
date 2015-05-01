class Invoice < ActiveRecord::Base
  belongs_to :member

  scope :open, -> { where('balance > 0') }
  scope :closed, -> { where('balance <= 0') }
  scope :diff_name, -> { joins(:member).where(
    "data->'first_name' != members.first_name OR " \
    "data->'last_name' != members.last_name"
  ) }
  scope :diff_zip, -> { joins(:member).where("data->'zip' != members.zip") }
  scope :during_year, ->(year) {
    where(
      'date >= ? AND date <= ?',
      Date.new(year).beginning_of_year,
      Date.new(year).end_of_year
    )
  }

  def status
    balance > 0 ? :open : :closed
  end

  def display_status
    I18n.t("invoice.status.#{status}")
  end
end
