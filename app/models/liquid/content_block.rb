class Liquid::ContentBlock < Liquid::Block
  attr :id, :title

  def initialize(_name, markup, _tokens)
    super
    attrs = parse_markup(markup)
    @id = attrs[:id].presence
    raise "missing content id, please specify one with (id: 'my_id')" unless @id

    @title = attrs[:title].presence
  end

  def raw_body
    raw = nodelist_to_string(@body.nodelist)
    "<div>#{raw}</div>"
  end

  def render(context)
    content = (context["#{@id}_content"] || super).strip
    return '' if content.blank?

    <<-HTML
      <div class="content-block" id="#{ @id }">
        #{@title && "<h2 class=\"content_title\">#{@title}</h2>" }
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

  def nodelist_to_string(nodelist)
    nodelist.map { |node|
      case node
      when String
        node
      when Liquid::Variable
        "{{#{node.raw}}}"
      when Liquid::Tag
        <<~LIQUID
          {% #{node.raw} %}
            #{nodelist_to_string(node.nodelist)}
          {% #{node.block_delimiter} %}
        LIQUID
      when Liquid::BlockBody
        nodelist_to_string(node.nodelist)
      end
    }.join.strip
  end
end
