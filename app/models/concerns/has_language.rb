module HasLanguage
  extend ActiveSupport::Concern

  included do
    attribute :language, :string, default: -> { Current.acp.languages.first }

    validates :language,
      presence: true,
      inclusion: { in: proc { Current.acp.languages } }
  end
end
