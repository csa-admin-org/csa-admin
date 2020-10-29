class Liquid::ButtonBlock < Liquid::Block
  def initialize(_name, url_name, _tokens)
     super
     @url_name = url_name
  end

  def render(context)
    url = context[@url_name]
    <<-HTML
    <table class="body-action" align="center" width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td align="center">
          <!-- Border based button https://litmus.com/blog/a-guide-to-bulletproof-buttons-in-email-design -->
          <table width="100%" border="0" cellspacing="0" cellpadding="0">
            <tr>
              <td align="center">
                <table border="0" cellspacing="0" cellpadding="0">
                  <tr>
                    <td>
                      <a href="#{ url }" class="button button--green" target="_blank">
                        #{ super }
                      </a>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    HTML
  end
end
