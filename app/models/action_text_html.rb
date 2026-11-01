# frozen_string_literal: true

# Shared Action Text HTML helpers for email and public feed rendering.
# Unwraps attachment wrapper tags while keeping the nested preview HTML
# (same approach as Rails mailer sanitization for gallery markup).
module ActionTextHtml
  module_function

  # Lexxy stores highlight colors as var(--highlight-N). Mail clients ignore
  # custom properties, so replace the known ones with a concrete color before
  # the sanitizer runs. Unknown vars are left for Loofah to drop.
  HIGHLIGHTS = {
    "--highlight-1" => "rgb(136, 118, 38)",
    "--highlight-2" => "rgb(185, 94, 6)",
    "--highlight-3" => "rgb(207, 0, 0)",
    "--highlight-4" => "rgb(216, 28, 170)",
    "--highlight-5" => "rgb(144, 19, 254)",
    "--highlight-6" => "rgb(5, 98, 185)",
    "--highlight-7" => "rgb(17, 138, 15)",
    "--highlight-8" => "rgb(148, 82, 22)",
    "--highlight-9" => "rgb(102, 102, 102)",
    "--highlight-bg-1" => "rgba(229, 223, 6, 0.3)",
    "--highlight-bg-2" => "rgba(255, 185, 87, 0.3)",
    "--highlight-bg-3" => "rgba(255, 118, 118, 0.3)",
    "--highlight-bg-4" => "rgba(248, 137, 216, 0.3)",
    "--highlight-bg-5" => "rgba(190, 165, 255, 0.3)",
    "--highlight-bg-6" => "rgba(124, 192, 252, 0.3)",
    "--highlight-bg-7" => "rgba(140, 255, 129, 0.3)",
    "--highlight-bg-8" => "rgba(221, 170, 123, 0.3)",
    "--highlight-bg-9" => "rgba(200, 200, 200, 0.3)"
  }.freeze

  def unwrap_attachments(html)
    strip_css_urls(resolve_highlights(html.to_s))
      .gsub(/<action-text-attachment\b[^>]*>/i, "")
      .gsub(%r{</action-text-attachment>}i, "")
  end

  def resolve_highlights(html)
    html.gsub(/var\((--highlight(?:-bg)?-\d)\)/) { HIGHLIGHTS.fetch(Regexp.last_match(1), Regexp.last_match(0)) }
  end

  # Loofah drops a top-level url() and leaves one nested in an allowed function,
  # such as linear-gradient. Strip those before it runs. Text outside style is
  # left alone.
  def strip_css_urls(html)
    html.gsub(/(\bstyle\s*=\s*)(["'])(.*?)\2/i) {
      prefix, quote, value = Regexp.last_match.captures
      %(#{prefix}#{quote}#{value.gsub(/url\s*\([^)]*\)/i, "")}#{quote})
    }
  end

  # Underline looks like a link. Drop the tag and Lexxy's class, keep the text.
  def strip_underline(html)
    html.to_s
      .gsub(%r{</?u\b[^>]*>}i, "")
      .gsub(/class="([^"]*)"/) {
        classes = Regexp.last_match(1).split(/\s+/) - [ "lexxy-content__underline" ]
        classes.empty? ? "" : %(class="#{classes.join(" ")}")
      }
  end
end
