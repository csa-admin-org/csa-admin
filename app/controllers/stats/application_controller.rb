class Stats::ApplicationController < ApplicationController
  before_action :authenticate!
  layout 'stats'

  private

  def authenticate!
    if Rails.env.production?
      stats_password = Current.acp.credentials(:stats_password)
      authenticate_or_request_with_http_basic do |username, password|
        username == 'STATS' && stats_password && password == stats_password
      end
    end
  end
end
