# frozen_string_literal: true

module UIHelper
  def menu_nav
    links = page.all("nav ul li a").map(&:text)
    links.pop # Remove User Account link
    links
  end
end
