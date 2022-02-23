module HeaderHelper
  def menu_nav
    links = page.all('nav ul li a').map(&:text)
    links.pop # Remove User Account link
    links
  end
end

RSpec.configure do |config|
  config.include(HeaderHelper)
end
