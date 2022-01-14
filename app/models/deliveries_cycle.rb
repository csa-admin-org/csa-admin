class DeliveriesCycle < ApplicationRecord
  include TranslatedAttributes
  include HasVisibility

  enum week_numbers: %i[all odd even], _suffix: true
  enum results: %i[all odd even], _suffix: true

  has_and_belongs_to_many :depots

  translated_attributes :name, :public_name

  default_scope { order_by_name }

  validates :name, :form_priority, presence: true

  def display_name; name end

  def public_name
    self[:public_names][I18n.locale.to_s].presence || name
  end

  def next_delivery
    (current_deliveries + future_deliveries).select { |d| d.date >= Date.current }.min_by(&:date)
  end

  def deliveries_count
    @deliveries_count ||= begin
      future_deliveries.any? ? future_deliveries.size : current_deliveries.size
    end
  end

  def current_deliveries
    @current_deliveries ||= deliveries(Current.fy_year)
  end

  def future_deliveries
    @future_deliveries ||= deliveries(Current.fy_year + 1)
  end

  def wdays=(wdays)
    super wdays.map(&:to_s) & Array(0..6).map(&:to_s)
  end

  def months=(months)
    super months.map(&:to_s) & Array(1..12).map(&:to_s)
  end

  private

  def deliveries(year)
    scoped =
      Delivery
        .where('EXTRACT(DOW FROM date) IN (?)', wdays)
        .where('EXTRACT(MONTH FROM date) IN (?)', months)
        .during_year(year)
    if odd_week_numbers?
      scoped = scoped.where('EXTRACT(WEEK FROM date)::integer % 2 = ?', 1)
    elsif even_week_numbers?
      scoped = scoped.where('EXTRACT(WEEK FROM date)::integer % 2 = ?', 0)
    end
    if odd_results?
      scoped = scoped.to_a.select.with_index { |_, i| (i + 1).odd? }
    elsif even_results?
      scoped = scoped.to_a.select.with_index { |_, i| (i + 1).even? }
    end
    scoped
  end
end
