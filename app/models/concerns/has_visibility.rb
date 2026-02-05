# frozen_string_literal: true

module HasVisibility
  extend ActiveSupport::Concern

  included do
    base_scope = respond_to?(:kept) ? :kept : :all
    scope :visible, -> { send(base_scope).where(visible: true) }
    scope :hidden, -> { send(base_scope).where(visible: false) }
  end
end
