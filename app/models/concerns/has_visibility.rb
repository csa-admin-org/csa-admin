# frozen_string_literal: true

module HasVisibility
  extend ActiveSupport::Concern

  included do
    scope :visible, -> { kept.where(visible: true) }
    scope :hidden, -> { kept.where(visible: false) }
  end
end
