# frozen_string_literal: true

module CapTestHelper
  def cap_token = "test-cap-token"

  def fill_in_cap
    page.find('input[name="cap-token"]', visible: false).set(cap_token)
  end
end
