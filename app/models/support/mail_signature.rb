# frozen_string_literal: true

require "nokogiri"

module Support
  # Client signatures, not the operator ++ sign-off. Gmail, Infomaniak,
  # and Thunderbird mark the block. Render drops data attributes, so a
  # trailing block of signature images is the same footer. A line that is
  # exactly "-- " is the RFC 3676 delimiter, including when it is only a
  # text node between breaks: everything after it is the signature.
  # A quoted original often ends with an unmarked sign-off and a short
  # contact card. That card is the same footer when every line after the
  # sign-off is contact data.
  class MailSignature
    CSS = ".gmail_signature, .gmail_signature_prefix, #Signature, [data-ik-opengraph-ignore], .moz-signature"
    DELIMITER = /\A--[[:space:]]*\z/
    SIGNATURE_IMAGE = %r{
      workspace\.storage\.infomaniak\.com/signature |
      googleusercontent\.com/mail-sig/
    }ix
    SIGNOFF = /
      \A
      (?:
        (?:bien[[:space:]]+)?(?:tr[èe]s[[:space:]]+)?cordialement |
        (?:bien[[:space:]]+)?amicalement |
        bien[[:space:]]+[àa][[:space:]]+(?:vous|toi) |
        (?:meilleures|sinc[èe]res|cordiales)[[:space:]]+salutations |
        salutations(?:[[:space:]]+distingu[ée]es)? |
        [àa][[:space:]]+bient[ôo]t |
        bonne[[:space:]]+(?:journ[ée]e|soir[ée]e|r[ée]ception|continuation) |
        (?:best|kind|warm)[[:space:]]+regards |
        yours[[:space:]]+sincerely |
        mit[[:space:]]+freundlichen[[:space:]]+gr(?:ü|ue)(?:ss|ß)en |
        (?:freundliche|viele|liebe|herzliche)[[:space:]]+gr(?:ü|ue)(?:ss|ß)e |
        cordiali[[:space:]]+saluti |
        (?:met[[:space:]]+)?vriendelijke[[:space:]]+groet(?:en)? |
        merci(?:[[:space:]]+(?:d'avance|beaucoup|pour[[:space:]]+(?:ton|votre)[[:space:]]+aide))? |
        (?:thanks|thank[[:space:]]+you)
      )
      [[:punct:][:space:]]*
      \z
    /ix
    EMAIL = /[\w.+\-]+@[\w.\-]+\.[A-Za-z]{2,}/
    URL = %r{https?://\S+|www\.\S+}i
    BARE_DOMAIN = /\b(?:[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?\.)+[a-z]{2,}\b/i
    ACRONYM = /\A(?=[\p{Lu}\d]{2,8}\z)(?=.*\p{Lu})(?=.*\d)[\p{Lu}\d]+\z/
    PHONE = %r{(?:\+|00|0)(?:[\s()./–—-]*\d){7,14}}
    MAX_CARD_LINES = 8

    def self.strip_fragment!(root)
      return unless root

      root.css(CSS).each(&:remove)
      drop_image_blocks!(root)
      drop_delimiter!(root)
      drop_signoff_block!(root)
    end

    def self.strip_text(text)
      source = text.to_s
      head, = source.split(/\n--[[:space:]]*\n/, 2)
      source = head.rstrip if head && head != source && head.present?
      strip_signoff_text(source)
    end

    def self.strip_signoff_text(text)
      source = text.to_s
      normalized = source.gsub("\r\n", "\n").gsub("\r", "\n")
      lines = normalized.lines
      index = lines.rindex { |line| signoff?(normalize_line(line)) }
      return source if index.nil?
      return source unless prose_before?(lines, index)

      tail = lines[(index + 1)..].map { |line| normalize_line(line) }.reject(&:blank?)
      return source unless contact_lines?(tail)

      lines[0..index].join.rstrip
    end
    private_class_method :strip_signoff_text

    # A cid image inside the signature must not become a file
    # attachment once the block is gone from the stored HTML.
    def self.without_signature_parts(attachments, html)
      hidden = signature_cids(html)
      return attachments if hidden.empty?

      Array(attachments).reject { |raw| hidden.include?(part_id(raw)) }
    end

    def self.drop_image_blocks!(root)
      return if fenced?(root)

      root.element_children.each { |child| drop_image_blocks!(child) }
      cut_image_block!(root)
    end
    private_class_method :drop_image_blocks!

    def self.cut_image_block!(root)
      last = root.element_children.reverse.find { |node| signature_block?(node) }
      last.remove if last && reply_before?(last)
    end
    private_class_method :cut_image_block!

    def self.signature_block?(node)
      images = node.css("img")
      images.any? && images.all? { |img| signature_image?(img) } && word?(node)
    end
    private_class_method :signature_block?

    def self.signature_image?(img)
      img["src"].to_s.match?(SIGNATURE_IMAGE)
    end
    private_class_method :signature_image?

    def self.signature_cids(html)
      root = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
      marked = root.css(CSS).flat_map { |node| cids_in(node) }
      outside = cids_in(root) - marked

      marked - outside
    end
    private_class_method :signature_cids

    def self.cids_in(node)
      node.css("img[src^='cid:']").map { |img|
        img["src"].delete_prefix("cid:").delete_prefix("<").delete_suffix(">")
      }
    end
    private_class_method :cids_in

    def self.part_id(raw)
      raw.to_h.stringify_keys["ContentID"].to_s.delete("<>").presence
    end
    private_class_method :part_id

    def self.reply_before?(node)
      node.xpath("preceding-sibling::*").any? { |sibling| word?(sibling) }
    end
    private_class_method :reply_before?

    def self.word?(node)
      node.text.gsub(/[[:space:]]/, "").present?
    end
    private_class_method :word?

    def self.drop_delimiter!(root)
      return if fenced?(root)

      root.element_children.each { |child| drop_delimiter!(child) }
      cut_delimiter!(content_children(root))
    end
    private_class_method :drop_delimiter!

    def self.cut_delimiter!(children)
      index = children.rindex { |node| delimiter?(node) }
      return unless index&.positive?
      return if following_content?(children, index) && !spaced?(children[index])

      children[index..].each(&:remove)
    end
    private_class_method :cut_delimiter!

    def self.fenced?(root)
      root.element? && %w[pre code].include?(root.name)
    end
    private_class_method :fenced?

    def self.delimiter?(node)
      return false if node.element? && node.css("img, a").any?

      node.text.match?(DELIMITER)
    end
    private_class_method :delimiter?

    def self.spaced?(node)
      node.text.match?(/\A--[[:space:]]+\z/)
    end
    private_class_method :spaced?

    def self.following_content?(children, index)
      children[(index + 1)..].any? { |node| node.text.match?(/\S/) }
    end
    private_class_method :following_content?

    def self.content_children(root)
      root.children.reject { |node|
        node.comment? || (node.text? && node.content.blank?)
      }
    end
    private_class_method :content_children

    def self.drop_signoff_block!(root)
      return if fenced?(root)

      root.element_children.each { |child| drop_signoff_block!(child) }
      cut_signoff_block!(root)
    end
    private_class_method :drop_signoff_block!

    def self.cut_signoff_block!(root)
      lines = lines_of(root)
      index = lines.rindex { |line| signoff_line?(line) }
      return unless index

      tail = lines[(index + 1)..]
      return if tail.blank?
      return unless content_before?(lines, index) || earlier_words?(root)
      return unless contact_block?(tail)

      tail.flatten.each(&:remove)
    end
    private_class_method :cut_signoff_block!

    def self.lines_of(root)
      children = content_children(root)
      return [] if children.empty?
      return children.map { |node| [ node ] } unless children.any? { |node| node.element? && node.name == "br" }

      children.chunk { |node| node.element? && node.name == "br" }.filter_map { |broken, group|
        group unless broken
      }
    end
    private_class_method :lines_of

    def self.signoff_line?(nodes)
      texts = plain_lines(nodes)
      texts.one? && signoff?(texts.first)
    end
    private_class_method :signoff_line?

    def self.signoff?(text)
      normalize_line(text).match?(SIGNOFF)
    end
    private_class_method :signoff?

    def self.content_before?(lines, index)
      lines[0...index].any? { |line|
        texts = plain_lines(line)
        texts.any? && texts.any? { |text| !signoff?(text) }
      }
    end
    private_class_method :content_before?

    def self.prose_before?(lines, index)
      lines[0...index].any? { |line|
        core = normalize_line(line)
        core.present? && !signoff?(core)
      }
    end
    private_class_method :prose_before?

    def self.earlier_words?(root)
      node = root
      while node && !node.document? && !node.fragment?
        return true if node.xpath("preceding-sibling::*").any? { |sibling| word?(sibling) }
        return true if node.xpath("preceding-sibling::text()").any? { |text| text.content.match?(/\S/) }

        node = node.parent
      end
      false
    end
    private_class_method :earlier_words?

    def self.contact_block?(lines)
      nodes = lines.flatten
      contact_lines?(lines.flat_map { |line| plain_lines(line) }, nodes)
    end
    private_class_method :contact_block?

    def self.contact_lines?(texts, nodes = [])
      return false if texts.empty? || texts.size > MAX_CARD_LINES
      return false if texts.sum(&:length) > 400
      return false if blocked_structure?(nodes)
      return false if texts.any? { |text| !contact_line?(text) }

      enough_signals?(texts, nodes)
    end
    private_class_method :contact_lines?

    def self.blocked_structure?(nodes)
      nodes.any? { |node|
        next unless node.element?

        node.matches?("pre, blockquote, ul, ol") || node.css("pre, blockquote, ul, ol").any?
      }
    end
    private_class_method :blocked_structure?

    def self.contact_line?(text)
      line = normalize_line(text)
      return true if line.match?(/\A(?:--+|—+|–+|_+)\z/)
      return true if phone_line?(line) || url_line?(line) || email_line?(line)
      return true if postal_line?(line) || street_line?(line)
      return true if phone_and_email_line?(line) || role_line?(line)

      name_line?(line)
    end
    private_class_method :contact_line?

    def self.enough_signals?(texts, nodes)
      signals = 0
      signals += 1 if texts.any? { |text| text.match?(EMAIL) } || nodes.any? { |node| mailto_link?(node) }
      signals += 1 if texts.any? { |text| phone_line?(text) || phone_and_email_line?(text) }
      signals += 1 if texts.any? { |text| site_line?(text) } || nodes.any? { |node| web_link?(node) }
      signals >= 2
    end
    private_class_method :enough_signals?

    def self.phone_line?(text)
      line = normalize_line(text).sub(
        /\A(?:t[ée]l(?:[ée]phone)?|tel(?:ephone)?|phone|mobile|gsm|portable)\s*[:.]?\s*/i,
        "")
      return false unless line.match?(/\A(?:\+|00|0)/)
      return false if line.match?(/\p{L}/)

      line.gsub(/\D/, "").length.between?(8, 15)
    end
    private_class_method :phone_line?

    def self.url_line?(text)
      line = normalize_line(text)
      line.match?(%r{\A(?:https?://|www\.)\S+\z}i) || line.match?(/\A#{BARE_DOMAIN.source}\z/i)
    end
    private_class_method :url_line?

    def self.site_line?(text)
      line = normalize_line(text)
      return true if url_line?(line)

      line.gsub(EMAIL, " ").match?(BARE_DOMAIN)
    end
    private_class_method :site_line?

    # A short "phone - email" line. A sentence that mentions both stays.
    def self.phone_and_email_line?(text)
      line = normalize_line(text)
      return false if line.length > 80 || line.match?(/\?/)
      return false unless line.match?(EMAIL)

      chunk = line.gsub(EMAIL, " ")[PHONE]
      return false unless chunk.to_s.gsub(/\D/, "").length.between?(8, 15)

      rest = line.gsub(EMAIL, " ").sub(chunk, " ")
      rest = rest.gsub(
        /\b(?:t[ée]l(?:[ée]phone)?|telephone|tel|phone|mobile|gsm|portable|courriel|e-?mail)\b/i,
        " ")
      rest.gsub(/[^\p{L}\p{N}]+/, " ").strip.blank?
    end
    private_class_method :phone_and_email_line?

    def self.role_line?(text)
      line = normalize_line(text)
      return false if line.length > 80 || line.match?(EMAIL) || line.match?(/[?;:!]/)

      had_site = line.match?(URL) || line.match?(BARE_DOMAIN)
      words = line.gsub(URL, " ").gsub(BARE_DOMAIN, " ")
      words = words.gsub(/[-–—|•·,\/]+/, " ").split(/[[:space:]]+/)
      return false if words.empty? || words.size > 6
      return false unless words.all? { |word| title_token?(word) }

      had_site || words.any? { |word| acronym?(word) }
    end
    private_class_method :role_line?

    def self.title_token?(word)
      acronym?(word) || word.match?(/\A\p{L}[\p{L}'’.-]*\z/)
    end
    private_class_method :title_token?

    def self.acronym?(word)
      word.match?(ACRONYM)
    end
    private_class_method :acronym?

    def self.email_line?(text)
      line = normalize_line(text)
      return false unless line.match?(EMAIL)

      rest = line.gsub(EMAIL, "").gsub(/[[:punct:]]+/, " ").strip
      rest.blank? || rest.match?(/\A(?:e-?mail|courriel|mail)\z/i)
    end
    private_class_method :email_line?

    def self.postal_line?(text)
      line = normalize_line(text)
      line.match?(/\A\d{4,5}\s+\p{L}[\p{L}\s.'-]{1,40}\z/) ||
        line.match?(/\A\p{L}[\p{L}\s.'-]{1,40}\s+\d{4,5}\z/)
    end
    private_class_method :postal_line?

    def self.street_line?(text)
      normalize_line(text).match?(/\A\d{1,4}\s+\p{L}[\p{L}\d\s.'-]{2,50}\z/)
    end
    private_class_method :street_line?

    def self.name_line?(text)
      line = normalize_line(text)
      return false if line.match?(EMAIL) || line.match?(URL)
      return false if line.match?(/[,:;!?]/)

      words = line.split(/[[:space:]]+/)
      return false unless words.size.between?(1, 6)

      words.all? { |word| !word.match?(/\d/) || acronym?(word) }
    end
    private_class_method :name_line?

    def self.mailto_link?(node)
      return false unless node.element?

      link_hrefs(node).any? { |href| href.match?(/\Amailto:/i) }
    end
    private_class_method :mailto_link?

    def self.web_link?(node)
      return false unless node.element?

      link_hrefs(node).any? { |href| href.match?(%r{\Ahttps?://}i) }
    end
    private_class_method :web_link?

    def self.link_hrefs(node)
      [ node["href"], *node.css("a").map { |link| link["href"] } ].compact
    end
    private_class_method :link_hrefs

    def self.plain_lines(nodes)
      clone = Nokogiri::HTML::DocumentFragment.parse("")
      Array(nodes).each { |node| clone.add_child(node.dup) }
      clone.css("br").each { |br| br.replace("\n") }
      clone.css("p, div, tr, li, td, th").each { |node| node.after("\n") }
      clone.text.lines.map { |line| normalize_line(line) }.reject(&:blank?)
    end
    private_class_method :plain_lines

    def self.normalize_line(text)
      text.to_s.tr("\u00a0", " ").gsub(/[[:space:]]+/, " ").strip
    end
    private_class_method :normalize_line
  end
end
