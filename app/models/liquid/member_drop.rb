class Liquid::MemberDrop < Liquid::Drop
  def initialize(member)
    @member = member
  end

  def name
    @member.name
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
    url(:members_membership, anchor: 'renewal')
  end

  private

  def url(name, **options)
    helper = Rails.application.routes.url_helpers
    helper.send("#{name}_url",
      { host: Current.acp.email_default_host }.merge(**options)
    ).gsub(/\/+\z/, '')
  end
end
