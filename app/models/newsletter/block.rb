class Newsletter
  class Block < ApplicationRecord
    include TranslatedRichTexts
    attr_accessor :titles, :template_id

    self.table_name = 'newsletter_blocks'

    belongs_to :newsletter

    translated_rich_texts :content

    def data_name
      "#{block_id}_content"
    end
  end
end
