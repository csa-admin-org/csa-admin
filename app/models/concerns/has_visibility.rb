module HasVisibility
  extend ActiveSupport::Concern

  included do
    scope :visible, -> { where(visible: true) }
    scope :hidden, -> { where(visible: false) }
  end
end
