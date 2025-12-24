# frozen_string_literal: true

class Liquid::MemberDrop < Liquid::Drop
  include NumbersHelper

  private(*NumbersHelper.public_instance_methods)

  def initialize(member, email: nil)
    @member = member
  end

  def name
    @member.name
  end

  def balance
    cur(@member.balance_amount.to_f)
  end

  def annual_fee
    return unless @member.annual_fee

    cur(@member.annual_fee.to_f)
  end

  def page_url
    url(:members_member)
  end

  def billing_url
    url(:members_billing)
  end

  def absences_url
    return unless Current.org.feature?("absence")

    url(:members_absences)
  end

  def activities_url
    return unless Current.org.feature?("activity")

    url(:members_activity_participations)
  end

  def membership_renewal_url
    url(:members_memberships, anchor: "renewal")
  end

  def memberships_url
    url(:members_memberships)
  end

  def deliveries_url
    url(:members_deliveries)
  end

  def billing_email
    !!@member.billing_email?
  end

  def shop_depot
    return unless @member.use_shop_depot?

    Liquid::DepotDrop.new(@member.shop_depot)
  end

  private

  def url(name, **options)
    helper = Rails.application.routes.url_helpers
    helper.send("#{name}_url",
      { host: Current.org.members_url }.merge(**options)
    ).gsub(/\/+\z/, "")
  end
end
