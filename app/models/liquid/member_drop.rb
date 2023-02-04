class Liquid::MemberDrop < Liquid::Drop
  include NumbersHelper

  private *NumbersHelper.public_instance_methods

  def initialize(member, email: nil)
    @member = member
  end

  def name
    @member.name
  end

  def balance
    cur(@member.balance_amount.to_f)
  end

  def page_url
    url(:members_member)
  end

  def billing_url
    url(:members_billing)
  end

  def activities_url
    url(:members_activity_participations)
  end

  def membership_renewal_url
    url(:members_memberships, anchor: 'renewal')
  end

  def billing_email
    !!@member.billing_email?
  end

  private

  def url(name, **options)
    helper = Rails.application.routes.url_helpers
    helper.send("#{name}_url",
      { host: Current.acp.email_default_host }.merge(**options)
    ).gsub(/\/+\z/, '')
  end
end
