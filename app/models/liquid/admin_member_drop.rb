class Liquid::AdminMemberDrop < Liquid::Drop
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
end
