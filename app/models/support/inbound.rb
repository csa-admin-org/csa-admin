# frozen_string_literal: true

module Support
  class Inbound
    Hop = Data.define(:body, :html) do
      def present?
        body.present? || html.present?
      end

      def blank?
        !present?
      end
    end

    attr_reader :from, :original_from, :reply, :original, :rfc_message_id,
      :attachments, :subject

    def self.parse(payload)
      new(payload)
    end

    def initialize(payload)
      @payload = payload.to_h.stringify_keys
      @from = InboundAddress.from_email(@payload)
      @rfc_message_id = InboundAddress.message_id_from(@payload)
      @attachments = @payload["Attachments"]
      @subject = Ticket.inbound_subject(@payload["Subject"])
      @reply = empty_hop
      @original = empty_hop
      parse
    end

    def blank?
      reply.blank? && original.blank?
    end

    def hops
      [ original ].select(&:present?)
    end

    def content
      reply.body.presence || original.body.presence ||
        ActionText::Content.new(reply.html.presence || original.html.to_s)
          .to_plain_text.presence ||
        ("—" if attachments.present?)
    end

    private

    def parse
      html = @payload["HtmlBody"]
      text = @payload["TextBody"]

      if html.present?
        reply_html, original_html = ReplyHtml.split_cited(html)
        reply_html = ReplyHtml.extract(html) if original_html.blank?
        @reply = hop_from_html(reply_html)
        @original = hop_from_html(original_html)
        @original_from = ReplyBody.original_from(plain(html))
      end

      @original_from ||= ReplyBody.original_from(text)
      @original = hop_from_text(ReplyBody.original(text)) if @original.blank?
      if @reply.blank?
        @reply = hop_from_text(ReplyBody.extract(
          text_body: text,
          stripped: @payload["StrippedTextReply"]))
      end
    end

    def hop_from_html(html)
      html = html.presence
      Hop.new(body: plain(html), html: html)
    end

    def hop_from_text(body)
      Hop.new(body: body.presence, html: nil)
    end

    def empty_hop
      Hop.new(body: nil, html: nil)
    end

    def plain(html)
      return if html.blank?

      ActionText::Content.new(html).to_plain_text.presence
    end
  end
end
