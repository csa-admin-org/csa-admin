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
    session&.owner || System.instance
  end

  private

  def set_current_session
    self.session ||= Current.session
  end
end
