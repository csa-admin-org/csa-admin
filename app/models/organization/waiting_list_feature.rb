# frozen_string_literal: true

module Organization::WaitingListFeature
  extend ActiveSupport::Concern

  def waiting_list?
    feature?("waiting_list")
  end
end
