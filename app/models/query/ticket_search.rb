# frozen_string_literal: true

module Query
  class TicketSearch
    DEFAULT_PER = 50
    MAX_PER = 50
    SNIPPET_RADIUS = 80
    TEST_SUBJECT = /\Atest(?: \d+)?\z/i
    EMAIL = /[\w.+-]+@[\w.-]+\.\w+/

    def self.run(q, token:, per: DEFAULT_PER, tenants: nil)
      new(q, token: token, per: per, tenants: tenants).run
    end

    def initialize(q, token:, per: DEFAULT_PER, tenants: nil)
      @q = q.to_s.strip
      raise Error, "empty query" if @q.blank?

      @token = token
      @tenants = tenants
      n = per.to_i
      n = DEFAULT_PER if n < 1
      @per = [ n, MAX_PER ].min
    end

    def run
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      hits = search_tenants
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
      hits.sort_by! { |hit| hit[:last_activity_at] }.reverse!
      truncated = hits.length > @per
      hits = hits.first(@per)

      {
        tickets: hits,
        meta: {
          row_count: hits.length,
          query_time_ms: elapsed_ms,
          page: 1,
          per_page: @per,
          has_more: truncated
        }
      }
    end

    private

    def search_tenants
      hits = []
      Walk.each(token: @token, tenants: @tenants) do
        hits.concat(hits_for_current_tenant)
      end
      hits
    end

    def hits_for_current_tenant
      Support::Ticket
        .text_cont(@q)
        .includes(:last_message, messages: :rich_text_html)
        .ordered_by_last_activity
        .filter_map { |ticket| hit_for(ticket) }
    end

    def hit_for(ticket)
      return if TEST_SUBJECT.match?(ticket.subject)

      match, snippet = match_for(ticket)
      {
        tenant: Tenant.current,
        token: ticket.token,
        subject: ticket.subject,
        last_activity_at: ticket.last_activity_at&.utc&.iso8601,
        state: ticket.state,
        match: match,
        snippet: snippet
      }
    end

    def match_for(ticket)
      ticket.messages.sort_by(&:id).each do |message|
        excerpt = excerpt_around(message.body)
        excerpt ||= excerpt_around(message.html.to_plain_text) if message.html.present?
        return [ message.author, excerpt ] if excerpt
      end

      [ "subject", excerpt_around(ticket.subject) || redact(ticket.subject) ]
    end

    def excerpt_around(text)
      source = text.to_s.gsub(/[[:space:]]+/, " ").strip
      return if source.blank?

      idx = source.downcase.index(@q.downcase)
      return unless idx

      start = [ idx - SNIPPET_RADIUS, 0 ].max
      finish = [ idx + @q.length + SNIPPET_RADIUS, source.length ].min
      chunk = source[start...finish]
      prefix = start.positive? ? "…" : ""
      suffix = finish < source.length ? "…" : ""
      redact("#{prefix}#{chunk}#{suffix}")
    end

    def redact(text)
      text.to_s.gsub(EMAIL, "[email]")
    end
  end
end
