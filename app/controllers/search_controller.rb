# frozen_string_literal: true

class SearchController < ApplicationController
  include ActivitiesHelper
  include ActiveAdmin::OrganizationSettingsHelper

  before_action :authenticate_admin!

  layout false

  MAX_RESULTS = 12
  MAX_SETTINGS_RESULTS = 3
  MAX_HANDBOOK_RESULTS = 3

  def index
    unless turbo_frame_request?
      return redirect_to root_path(search: params[:q])
    end

    @query = params[:q].to_s.strip
    @settings_results = organization_setting_search_results(@query).first(MAX_SETTINGS_RESULTS)
    @handbook_results = Handbook.search(@query, locale: I18n.locale).first(MAX_HANDBOOK_RESULTS)
    @results = SearchEntry.lookup(@query, limit: MAX_RESULTS - @settings_results.size - @handbook_results.size)
  end
end
