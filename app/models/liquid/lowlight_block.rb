class Liquid::LowlightBlock < Liquid::Block
  def initialize(_name, _args, _tokens)
     super
  end

  def render(context)
    <<-HTML
    <table class="attributes spaced" width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td class="attributes_lowlight">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td>
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
