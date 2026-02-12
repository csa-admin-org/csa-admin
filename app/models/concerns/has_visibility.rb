# frozen_string_literal: true

module HasVisibility
  extend ActiveSupport::Concern

  included do
    scope :visible, -> { (respond_to?(:kept) ? kept : all).where(visible: true) }
    scope :hidden, -> { (respond_to?(:kept) ? kept : all).where(visible: false) }
  end
end
