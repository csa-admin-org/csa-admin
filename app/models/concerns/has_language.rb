module HasLanguage
  extend ActiveSupport::Concern

  included do
    validates :language,
      presence: true,
      inclusion: { in: proc { Current.acp.languages } }
  end
end
