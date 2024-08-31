# frozen_string_literal: true

module HasLanguage
  extend ActiveSupport::Concern

  included do
    attribute :language, :string, default: -> { Current.org.languages.first }

    validates :language,
      presence: true,
      inclusion: { in: proc { Current.org.languages } }
  end
end
