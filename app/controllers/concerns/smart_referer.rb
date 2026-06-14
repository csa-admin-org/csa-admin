# frozen_string_literal: true

module SmartReferer
  extend ActiveSupport::Concern

  COOKIE = :smart_referer_context
  DURATION = 3.minutes
  EMPTY_CONTEXT = ->(_) { {} }
  CONTEXT_BUILDERS = {
    "Member" => ->(record) { { "member_id" => record.id.to_s, "invoice_id" => nil } },
    "Membership" => ->(record) { { "member_id" => record.member_id.to_s, "invoice_id" => nil } },
    "Invoice" => ->(record) { { "invoice_id" => record.id.to_s, "member_id" => record.member_id.to_s } },
    "Delivery" => ->(record) { { "delivery_id" => record.id.to_s, "_delivery_gid" => record.to_global_id.to_s } },
    "Activity" => ->(record) { { "activity_id" => record.id.to_s } }
  }.freeze

  included do
    helper_method :smart_referer_context
  end

  private

  def remember_smart_referer_context
    return unless smart_referer_context_recordable?

    save_smart_referer_context(smart_referer_context_for(resource))
  end

  def smart_referer_context
    context = load_smart_referer_context
    return clear_smart_referer_context if smart_referer_context_expired?(context)

    context.except("expires_at")
  end

  def smart_referer_context_for(record)
    CONTEXT_BUILDERS.fetch(record.class.name, EMPTY_CONTEXT).call(record)
  end

  def smart_referer_context_recordable?
    action_name == "show" && request.format.html? && response.successful? && respond_to?(:resource, true)
  end

  def save_smart_referer_context(context)
    return if context.empty?

    cookies.encrypted[COOKIE] = smart_referer_cookie(context)
  end

  def smart_referer_cookie(context)
    expires_at = DURATION.from_now
    { value: smart_referer_cookie_value(context, expires_at), expires: expires_at, httponly: true, same_site: :lax }
  end

  def smart_referer_cookie_value(context, expires_at)
    smart_referer_context.merge(context).compact.merge("expires_at" => expires_at.to_i).to_json
  end

  def load_smart_referer_context
    JSON.parse(cookies.encrypted[COOKIE].presence || "{}")
  rescue JSON::ParserError, TypeError
    {}
  end

  def clear_smart_referer_context
    cookies.delete(COOKIE)
    {}
  end

  def smart_referer_context_expired?(context)
    expires_at = context["expires_at"]
    expires_at.blank? || Time.zone.at(expires_at.to_i).past?
  end
end
