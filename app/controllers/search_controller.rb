# frozen_string_literal: true

class SearchController < ApplicationController
  before_action :authenticate_admin!

  layout false

  MAX_RESULTS = 12
  MAX_HANDBOOK_RESULTS = 3

  # GET /search?q=...
  # Returns HTML fragments for the search modal results container.
  # When accessed directly (not via Turbo Frame), redirects to the
  # dashboard with the search modal pre-opened.
  def index
    unless turbo_frame_request?
      return redirect_to root_path(search: params[:q])
    end

    @query = params[:q].to_s.strip
    @handbook_results = Handbook.search(@query, locale: I18n.locale).first(MAX_HANDBOOK_RESULTS)
    @results = SearchEntry.lookup(@query, limit: MAX_RESULTS - @handbook_results.size)
  end
end
