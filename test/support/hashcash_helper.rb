# frozen_string_literal: true

module HashcashHelper
  def mint_hashcash(resource = nil)
    resource ||= Capybara.app_host ? URI.parse(Capybara.app_host).host : "members.acme.test"
    ActiveHashcash::Stamp.mint(resource).to_s
  end

  def fill_in_hashcash(resource = nil)
    stamp = mint_hashcash(resource)
    page.find('input[name="hashcash"]', visible: false).set(stamp)
  end
end
