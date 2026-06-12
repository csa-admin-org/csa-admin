# frozen_string_literal: true

module CapVerifiable
  extend ActiveSupport::Concern

  included do
    before_action :verify_cap, only: :create
  end

  private

  def verify_cap
    token = params["cap-token"]
    return cap_after_failure if token.blank?
    return if Cap::Verifier.skip?

    cap_after_failure unless Cap::Verifier.verify(token)
  end

  def cap_after_failure
    raise NotImplementedError
  end
end
