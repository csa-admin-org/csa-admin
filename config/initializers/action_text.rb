# frozen_string_literal: true

# Apple Mail replies can include a real <table>. The HTML4 safe list drops
# table, thead, tbody, tr, th, and td, so the ticket page shows the cells as
# one paragraph. Allow them on Action Text render only.
#
# Lexxy 1.0.4 sets its render list in after_initialize, after eager load.
# Replacing the list from config/initializers runs first, so production and CI
# keep video, audio, source, embed, and CSS var(). Install from an initializer
# that follows lexxy.sanitization. The editor rejects those uploads. Do not
# leave them on the render list.
#
# Lexxy highlight colors are inline `var(--highlight-N)`. Resolve the known
# ones to a concrete color before the sanitizer runs. Lexxy also adds `var` to
# Loofah's CSS functions, which keeps a nested `url()` inside an unknown var.
# Drop that function so a leftover var is removed. The editor loads the stored
# body, not this render, so the toolbar still sees the vars.
module ActionTextHighlightColors
  def self.install
    helper = ActionText::ContentHelper
    extra = %w[
      action-text-attachment figure figcaption
      s
      table thead tbody tfoot tr th td caption colgroup col
    ]
    rejected = %w[video audio source embed]
    base = helper.sanitizer.class.allowed_tags
    helper.allowed_tags = (Array(base) + extra - rejected).uniq
    Loofah::HTML5::SafeList::ALLOWED_CSS_FUNCTIONS.delete("var")
    helper.prepend(self) unless helper.ancestors.include?(self)
  end

  def sanitize_action_text_content(content)
    html = ActionTextHtml.resolve_highlights(content.to_html)
    html = ActionTextHtml.strip_css_urls(html)
    html = ActionTextHtml.strip_underline(html)
    # Re-wrapping canonicalizes and strips the rendered attachment.
    super(ActionText::Content.new(html, canonicalize: false))
  end
end
