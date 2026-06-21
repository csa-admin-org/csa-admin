# frozen_string_literal: true

# Shared concern for models that track the session (and thus the actor)
# responsible for a change. Used by Audit and BasketOverride.
module Sessionable
  extend ActiveSupport::Concern

  included do
    belongs_to :session, optional: true
    before_validation :set_current_session, on: :create
  end

  def actor
    session&.owner || fallback_actor
  end

  private

  def fallback_actor
    if created_at && created_at < Session::RETENTION.ago
      Unavailable.instance
    else
      System.instance
    end
  end

  def set_current_session
    self.session ||= Current.session
  end
end
