class Liquid::HighlightBlock < Liquid::Block
  def initialize(_name, _args, _tokens)
     super
  end

  def render(context)
    <<-HTML
    <table class="attributes" width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td class="attributes_content">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td class="attributes_item">
                #{ super }
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    HTML
  end
end
