class Newsletter
  class Attachment < ApplicationRecord
    self.table_name = "newsletter_attachments"

    belongs_to :newsletter

    has_one_attached :file

    validates :file, presence: true
  end
end
