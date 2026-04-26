# frozen_string_literal: true

module ReadOnlyAdminOriginatedMemberSession
  extend ActiveSupport::Concern

  private

  def ensure_admin_originated_session_is_read_only!
    return if Rails.env.development?
    return unless current_member
    return unless current_session&.admin_originated?
    return unless request.post? || request.patch? || request.put? || request.delete?
    return if allow_admin_originated_session_write?

    redirect_back(
      fallback_location: members_member_path,
      status: :see_other,
      alert: t("members.read_only_sessions.alert"))
  end

  def allow_admin_originated_session_write?
    false
  end
end
