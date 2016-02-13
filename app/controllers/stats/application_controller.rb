class Stats::ApplicationController < ApplicationController
  before_action :authenticate!
  layout 'stats'

  private

  def authenticate!
    if Rails.env.production?
      authenticate_or_request_with_http_basic do |username, password|
        username == 'RAVE' && password == ENV['STATS_PASSWORD']
      end
    end
  end
end
