class InvoiceTotal
  include HalfdaysHelper
  include ActionView::Helpers::UrlHelper

  def self.all
    scopes = %w[Membership]
    scopes << 'AnnualFee' if Current.acp.annual_fee?
    scopes << 'ACPShare' if Current.acp.share?
    scopes << 'HalfdayParticipation'
    scopes << 'Other' if Invoice.current_year.not_canceled.other_type.any?
    all = scopes.flatten.map { |scope| new(scope) }
    sum = all.sum(&:price)
    remaining = new('RemainingMembership')

    all << OpenStruct.new(price: sum)
    all << remaining
    all << OpenStruct.new(price: sum + remaining.price)
  end

  attr_reader :scope

  def initialize(scope)
    @memberships = Membership.joins(:member).where(members: { salary_basket: false }).current_year
    @invoices = Invoice.current_year.not_canceled
    @scope = scope
  end

  def title
    case scope
    when 'Membership'
      link_to_invoices Membership.model_name.human(count: 2)
    when 'RemainingMembership'
      I18n.t('billing.remaining_memberships')
    when 'AnnualFee'
      link_to_invoices(I18n.t('billing.annual_fees'), %w[Membership AnnualFee])
    when 'ACPShare'
      link_to_invoices I18n.t('billing.acp_shares')
    when 'HalfdayParticipation'
      link_to_invoices halfdays_human_name
    when 'Other'
      link_to_invoices I18n.t('billing.other')
    end
  end

  def price
    @price ||=
      case scope
      when 'Membership'
        @invoices.sum(:memberships_amount)
      when 'RemainingMembership'
        invoices_total = @invoices.sum(:memberships_amount)
        memberships_total =
          @memberships
            .joins(:baskets)
            .sum('baskets.quantity * (baskets.basket_price + baskets.depot_price)') +
          @memberships
            .joins(memberships_basket_complements: :basket_complement)
            .merge(BasketComplement.annual_price_type)
            .sum('memberships_basket_complements.quantity * memberships_basket_complements.price') +
          @memberships
            .joins(baskets: :baskets_basket_complements)
            .sum('baskets_basket_complements.quantity * baskets_basket_complements.price') +
          @memberships
            .sum('halfday_works_annual_price + basket_complements_annual_price_change + baskets_annual_price_change')
        [memberships_total - invoices_total, 0].max
      when 'AnnualFee'
        @invoices.sum(:annual_fee)
      else
        @invoices.where(object_type: scope).sum(:amount)
      end
  end

  private

  def link_to_invoices(title, object_types = scope)
    fy = Current.fiscal_year
    url_helpers = Rails.application.routes.url_helpers
    link_to title, url_helpers.invoices_path(
      scope: :all_without_canceled,
      q: {
        object_type_in: object_types,
        date_gteq: fy.beginning_of_year,
        date_lteq: fy.end_of_year
      })
  end
end
