# frozen_string_literal: true

class Members::BaseController < ApplicationController
  layout "members"

  before_action :authenticate_member!
  around_action :set_time_zone

  helper_method :current_member

  private

  def authenticate_member!
    if !current_member
      cookies.delete(:session_id)
      redirect_to members_login_path, alert: t("sessions.flash.required")
    elsif current_session&.expired?
      cookies.delete(:session_id)
      redirect_to members_login_path, alert: t("sessions.flash.expired")
    else
      add_appsignal_tags
      update_last_usage(current_session)
    end
  end

  def current_member
    current_session&.member
  end

  def set_time_zone
    time_zone = current_member&.time_zone || Current.org.time_zone
    Time.use_zone(time_zone) { yield }
  end

  def set_locale
    params_locale = params[:locale]&.first(2)
    if params_locale.in?(Current.org.languages)
      cookies.permanent[:locale] = params_locale
    end
    unless cookies[:locale].in?(Current.org.languages)
      cookies.delete(:locale)
    end
    I18n.locale =
      current_member&.language ||
      cookies[:locale] ||
      Current.org.languages.first
  end

  def add_appsignal_tags
    Appsignal.add_tags(
      member_id: current_member.id,
      session_id: current_session.id)
  end

  def current_shop_delivery
    return unless Current.org.feature?("shop")

    @current_shop_delivery ||=
      Delivery
        .shop_open
        .where(id: coming_delivery_ids)
        .next
  end
  helper_method :current_shop_delivery

  def next_shop_delivery
    return unless Current.org.feature?("shop")
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
    return [] unless Current.org.feature?("shop")
    return [] unless shop_depot = current_member.shop_depot

    @shop_special_deliveries ||=
      Shop::SpecialDelivery.coming.open.select { |sd|
        sd.shop_open?(depot_id: shop_depot.id, ignore_closing_at: true)
      }
  end
  helper_method :shop_special_deliveries

  def coming_delivery_ids
    if current_member.use_shop_depot?
      depot = current_member.shop_depot
      Delivery
        .coming
        .select { |delivery|
          delivery.shop_open?(depot_id: depot.id, ignore_closing_at: true) &&
            depot.include_delivery?(delivery)
        }
        .map(&:id)
    else
      current_member
        .baskets
        .coming
        .includes(:delivery)
        .select { |basket|
          basket.delivery.shop_open?(depot_id: basket.depot_id, ignore_closing_at: true)
        }
        .map(&:delivery_id)
    end
  end
end
