# frozen_string_literal: true

module Organization::PriceReductionsFeature
  extend ActiveSupport::Concern

  included do
    translated_rich_texts :member_form_price_reductions_text
  end
end
