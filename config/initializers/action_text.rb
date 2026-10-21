# frozen_string_literal: true

# Apple Mail replies can include a real <table>. The HTML4 safe list drops
# table, thead, tbody, tr, th, and td, so the ticket page shows the cells as
# one paragraph. Allow them on Action Text render only.
Rails.application.config.after_initialize do
  helper = ActionText::ContentHelper
  helper.allowed_tags = helper.sanitizer.class.allowed_tags + %w[
    action-text-attachment figure figcaption
    table thead tbody tfoot tr th td caption colgroup col
  ]
end
