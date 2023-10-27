class InvoiceTotal
  include ActivitiesHelper
  include ActionView::Helpers::UrlHelper

  def self.all(year)
    scopes = %w[Membership]
    scopes << 'AnnualFee' if Current.acp.annual_fee?
    scopes << 'ACPShare' if Current.acp.share?
    scopes << 'Shop::Order' if Current.acp.feature?('shop')
    scopes << 'ActivityParticipation' if Current.acp.feature?('activity')
    scopes << 'Other' if Invoice.current_year.not_canceled.other_type.any?
    all = scopes.flatten.map { |scope| new(scope, year) }
    sum = all.sum(&:price)
    remaining = new('RemainingMembership', year)

    all << OpenStruct.new(price: sum)
    all << remaining
    all << OpenStruct.new(price: sum + remaining.price)
  end

  attr_reader :scope

  def initialize(scope, year)
    @memberships = Membership.joins(:member).where(members: { salary_basket: false }).during_year(year)
    @invoices = Invoice.during_year(year).not_canceled
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
    when 'Shop::Order'
      link_to_invoices I18n.t('shop.title_orders', count: 2)
    when 'ActivityParticipation'
      link_to_invoices activities_human_name
    when 'NewMemberFee'
      link_to_invoices I18n.t('invoices.object_type.new_member_fee')
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
        memberships_total = @memberships.sum(:price)
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
        during_year: fy.year
      })
  end
end
