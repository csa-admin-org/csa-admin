class Members::BaseController < ApplicationController
  layout 'members'
  before_action :authenticate_member!

  helper_method :current_member

  private

  def authenticate_member!
    if !current_member
      cookies.delete(:session_id)
      redirect_to members_login_path, alert: t('sessions.flash.required')
    elsif current_session&.expired?
      cookies.delete(:session_id)
      redirect_to members_login_path, alert: t('sessions.flash.expired')
    else
      set_sentry_user
      update_last_usage(current_session)
    end
  end

  def current_member
    current_session&.member
  end

  def set_locale
    if params[:locale].in?(Current.acp.languages)
      cookies.permanent[:locale] = params[:locale]
    end
    unless cookies[:locale].in?(Current.acp.languages)
      cookies.delete(:locale)
    end
    I18n.locale =
      current_member&.language ||
      cookies[:locale] ||
      Current.acp.languages.first
  end

  def set_sentry_user
    Sentry.set_user(
      id: "member_#{current_member.id}",
      session_id: current_session.id)
  end

  def current_shop_delivery
    return unless Current.acp.feature?('shop')

    @current_shop_delivery ||=
      Delivery
        .shop_open
        .where(id: coming_delivery_ids)
        .next
  end
  helper_method :current_shop_delivery

  def next_shop_delivery
    return unless Current.acp.feature?('shop')
    return unless current_shop_delivery

    @next_shop_delivery ||=
      Delivery
        .shop_open
        .where.not(id: current_shop_delivery.id)
        .where(id: coming_delivery_ids)
        .next
  end
  helper_method :next_shop_delivery

  def shop_special_deliveries
    return unless Current.acp.feature?('shop')

    @shop_special_deliveries ||= Shop::SpecialDelivery.coming.open.select(&:shop_open?)
  end
  helper_method :shop_special_deliveries

  def coming_delivery_ids
    if current_member.shop_depot
      Delivery.coming.pluck(:id)
    else
      current_member.baskets.coming.pluck(:delivery_id)
    end
  end
end
