class Liquid::ContentBlock < Liquid::Block
  attr :id, :title

  EMPTY_TRIX_CONTENT = "<div class=\"trix-content\">\n  \n</div>"
  TEMPLATE_EMPTY_TRIX_CONTENT = "<div class=\"trix-content\">\n  <div></div>\n</div>"

  def initialize(_name, markup, _tokens)
    super
    attrs = parse_markup(markup)
    @id = attrs[:id].presence
    raise "missing content id, please specify one with (id: 'my_id')" unless @id

    @title = attrs[:title].presence
  end

  def raw_body
    raw = @body.nodelist.map { |node|
      node.is_a?(String) ? node : "{{#{node.raw}}}"
    }.join.strip
    "<div>#{raw}</div>"
  end

  def render(context)
    content = (context["#{@id}_content"] || super).strip
    return '' if content.blank?
    return '' if content == EMPTY_TRIX_CONTENT
    return '' if content == TEMPLATE_EMPTY_TRIX_CONTENT

    <<-HTML
      <div class="content-block" id="#{ @id }">
        #{ @title && "<h2 class=\"content_title\">#{@title}</h2>" }
        #{content}
      </div>
    HTML
  end

  private

  def parse_markup(markup)
    markup.scan(Liquid::TagAttributes).map do |key, value|
      value = value.gsub(/\A['":]|['"]\z/, '').strip if value
      [key, value]
    end.to_h.symbolize_keys
  end
end
