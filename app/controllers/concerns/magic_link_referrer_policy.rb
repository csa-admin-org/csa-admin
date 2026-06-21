# frozen_string_literal: true

module MagicLinkReferrerPolicy
  extend ActiveSupport::Concern

  included do
    before_action :set_no_referrer_policy, only: :show
  end

  private

  def set_no_referrer_policy
    response.headers["Referrer-Policy"] = "no-referrer"
  end
end
