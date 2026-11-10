# frozen_string_literal: true

require "nokogiri"

module Support
  # Infomaniak Mail sends a reaction as a banner plus a footer.
  # The message is the emoji.
  class MailReaction
    LINK = "infomaniak.com/gtl/apps.kmail"
    GRAPHEME = /[\p{Emoji_Presentation}\p{Extended_Pictographic}](?:\uFE0F|\p{Emoji_Modifier})*/
    NOTICE = /\A\s*(#{GRAPHEME.source})[^\n]*\n+[^\n]*Infomaniak Mail\s*\z/

    def self.collapse!(root)
      return unless root

      root.css("a[href*='#{LINK}']").each { |link| collapse_link!(link) }
    end

    def self.collapse_text(text)
      text.to_s.sub(NOTICE, '\1')
    end

    def self.collapse_link!(link)
      block = link.ancestors.find { |node| node.element? && node.at_css("table") }
      emoji = reaction_emoji(block)
      block.replace(emoji_node(block, emoji)) if block && emoji
    end
    private_class_method :collapse_link!

    def self.reaction_emoji(block)
      return unless block

      block.css("span").map { |node| node.text.strip }.find { |text|
        text.match?(/\A#{GRAPHEME.source}\z/)
      }
    end
    private_class_method :reaction_emoji

    def self.emoji_node(block, emoji)
      node = Nokogiri::XML::Node.new("div", block.document)
      node.content = emoji
      node
    end
    private_class_method :emoji_node
  end
end
