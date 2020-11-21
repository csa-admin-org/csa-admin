class Liquid::MemberDrop < Liquid::Drop
  def initialize(member)
    @member = member
  end

  def name
    @member.name
  end

  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .member_url(@member.id, {}, host: Current.acp.email_default_host)
  end

  def member_url
    Rails
      .application
      .routes
      .url_helpers
      .members_member_url(host: Current.acp.email_default_host)
  end
end
