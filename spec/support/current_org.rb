# frozen_string_literal: true

module CurrentOrg
  extend self

  def current_org
    @current_org ||= Organization.instance
  end

  def reset
    @current_org = nil
  end
end

RSpec.configure do |config|
  config.include(CurrentOrg)

  config.after(:each) { CurrentOrg.reset }
end
