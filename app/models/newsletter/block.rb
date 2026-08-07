# frozen_string_literal: true

class Newsletter
  class Block < ApplicationRecord
    include TranslatedRichTexts
    include Liquidable

    attr_accessor :titles, :template_id, :public_content, :public_feed

    self.table_name = "newsletter_blocks"

    belongs_to :newsletter

    translated_rich_texts :content

    validate :contents_must_be_valid

    def data_name
      "#{block_id}_content"
    end

    def public_content?
      !!public_content
    end

    def public_feed?
      !!public_feed
    end

    private

    def contents_must_be_valid
      validate_liquid(:contents)
      validate_html(:contents)
    end
  end
end
