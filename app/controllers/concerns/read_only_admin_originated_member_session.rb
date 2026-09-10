# frozen_string_literal: true

module ReadOnlyAdminOriginatedMemberSession
  extend ActiveSupport::Concern

  included do
    helper_method :admin_originated_session_read_only?
  end

  private

  def ensure_admin_originated_session_is_read_only!
    return unless admin_originated_session_read_only?
    return unless request.post? || request.patch? || request.put? || request.delete?
    return if allow_admin_originated_session_write?

    redirect_back(
      fallback_location: members_member_path,
      status: :see_other,
      alert: t("members.read_only_sessions.alert"))
  end

  def admin_originated_session_read_only?
    return false if Rails.env.development? || Tenant.demo?
    return false unless current_member

    current_session&.admin_originated?
  end

  def allow_admin_originated_session_write?
    false
  end
end
