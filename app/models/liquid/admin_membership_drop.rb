# frozen_string_literal: true

class Liquid::AdminMembershipDrop < Liquid::Drop
  def initialize(membership)
    @membership = membership
  end

  def id
    @membership.id
  end

  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .membership_url(@membership.id, {}, host: Current.org.admin_url)
  end

  def ended_on
    I18n.l(@membership.ended_on)
  end

  def renewal_note
    @membership.renewal_note
  end

  def renewal_annual_fee
    @membership.renewal_annual_fee
  end
end
