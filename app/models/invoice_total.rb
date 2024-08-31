# frozen_string_literal: true

class InvoiceTotal
  include ActivitiesHelper
  include ActionView::Helpers::UrlHelper

  def self.all(year)
    scopes = %w[Membership]
    scopes << "AnnualFee" if Current.org.annual_fee?
    scopes << "Share" if Current.org.share?
    scopes << "Shop::Order" if Current.org.feature?("shop")
    scopes << "ActivityParticipation" if Current.org.feature?("activity")
    scopes << "Other" if Invoice.current_year.not_canceled.other_type.any?
    all = scopes.flatten.map { |scope| new(scope, year) }
    sum = all.sum(&:price)
    remaining = new("RemainingMembership", year)

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
    when "Membership"
      link_to_invoices Membership.model_name.human(count: 2)
    when "RemainingMembership"
      I18n.t("billing.remaining_memberships")
    when "AnnualFee"
      link_to_invoices(I18n.t("billing.annual_fees"), %w[Membership AnnualFee])
    when "Share"
      link_to_invoices I18n.t("billing.shares")
    when "Shop::Order"
      link_to_invoices I18n.t("shop.title_orders", count: 2)
    when "ActivityParticipation"
      link_to_invoices activities_human_name
    when "NewMemberFee"
      link_to_invoices I18n.t("invoices.entity_type.new_member_fee")
    when "Other"
      link_to_invoices I18n.t("billing.other")
    end
  end

  def price
    @price ||=
      case scope
      when "Membership"
        @invoices.sum(:memberships_amount)
      when "RemainingMembership"
        invoices_total = @invoices.sum(:memberships_amount)
        memberships_total = @memberships.sum(:price)
        [ memberships_total - invoices_total, 0 ].max
      when "AnnualFee"
        @invoices.sum(:annual_fee)
      else
        @invoices.where(entity_type: scope).sum(:amount)
      end
  end

  private

  def link_to_invoices(title, entity_types = scope)
    fy = Current.fiscal_year
    url_helpers = Rails.application.routes.url_helpers
    link_to title, url_helpers.invoices_path(
      scope: :all,
      q: {
        entity_type_in: entity_types,
        during_year: fy.year
      })
  end
end
