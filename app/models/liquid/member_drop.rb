class Liquid::MemberDrop < Liquid::Drop
  def initialize(member)
    @member = member
  end

  def name
    @member.name
  end

  def page_url
    Rails
      .application
      .routes
      .url_helpers
      .members_member_url(host: Current.acp.email_default_host)
      .gsub(/\/\z/, '')
  end

  def billing_url
    Rails
      .application
      .routes
      .url_helpers
      .members_billing_url(host: Current.acp.email_default_host)
      .gsub(/\/\z/, '')
  end

  def activities_url
    Rails
      .application
      .routes
      .url_helpers
      .members_activities_url(host: Current.acp.email_default_host)
      .gsub(/\/\z/, '')
  end
end
