class Liquid::HighlightListBlock < Liquid::Block
  def initialize(_name, _args, _tokens)
     super
  end

  def render(context)
    lines =
      super.lines.map(&:chomp).map { |l|
        l.gsub("<div>", "").gsub("</div>", "").strip.presence
      }.compact
    lines.map! do |line|
      <<-HTML
      <tr>
        <td class="attributes_item">
          #{ line }
        </td>
      </tr>
      HTML
    end

    <<-HTML
    <table class="attributes" width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td class="attributes_highlight">
          <table width="100%" cellpadding="0" cellspacing="0">
            #{ lines.join("\n") }
          </table>
        </td>
      </tr>
    </table>
    HTML
  end
end
