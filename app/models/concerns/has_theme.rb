# frozen_string_literal: true

module HasTheme
  extend ActiveSupport::Concern

  THEMES = %w[system light dark].freeze

  included do
    attribute :theme, :string, default: "system"

    validates :theme,
      presence: true,
      inclusion: { in: THEMES }
  end
end
