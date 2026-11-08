# frozen_string_literal: true

# Stores a public campaign code from ?ref= or ?promo= on the parent domain.
# Same cookie as the public site: name, lifetime, and flags. Unsigned, so a
# public page can write it without the app secret. Never a session or a member id.
module PromotionCookie
  extend ActiveSupport::Concern

  COOKIE = :ref
  TTL = 90.days
  CODE = /\A[A-Za-z0-9._-]{1,64}\z/

  included do
    before_action :capture_promotion
    helper_method :current_promotion, :invalid_promotion
  end

  def current_promotion
    return @current_promotion if defined?(@current_promotion)

    @current_promotion = Promotion.find_redeemable(cookies[COOKIE])
  end

  # A known code that is no longer redeemable. Shown once, then the cookie is cleared.
  def invalid_promotion
    @invalid_promotion
  end

  private

  def capture_promotion
    incoming = params[:ref].presence || params[:promo].presence
    if incoming
      store_promotion_cookie(incoming)
    elsif cookies[COOKIE].present? && current_promotion.nil?
      note_invalid_promotion(cookies[COOKIE])
      clear_promotion_cookie
    end
  end

  def store_promotion_cookie(code)
    return clear_promotion_cookie unless CODE.match?(code)

    found = Promotion.find_redeemable(code)
    if found
      cookies[COOKIE] = promotion_cookie_options(code.strip)
      @current_promotion = found
      @invalid_promotion = nil
    else
      note_invalid_promotion(code)
      clear_promotion_cookie
    end
  end

  def note_invalid_promotion(code)
    @invalid_promotion = Promotion.find_by_code(code)
  end

  def clear_promotion_cookie
    cookies.delete(COOKIE, domain: promotion_cookie_domain, path: "/")
    @current_promotion = nil
  end

  def promotion_cookie_options(code)
    {
      value: code,
      expires: TTL.from_now,
      secure: request.ssl?,
      same_site: :lax,
      path: "/",
      domain: promotion_cookie_domain
    }
  end

  # Parent of the host that served the page, so a local .test host does not
  # write a .ch cookie the browser will drop.
  def promotion_cookie_domain
    ".#{PublicSuffix.parse(request.host).domain}"
  end
end
