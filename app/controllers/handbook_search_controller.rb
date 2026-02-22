# frozen_string_literal: true

class HandbookSearchController < ApplicationController
  before_action :authenticate_admin!

  layout false

  def show
    unless turbo_frame_request?
      return redirect_to handbook_page_path(params[:page] || :getting_started)
    end

    @query = params[:q].to_s.strip
    @current_page = params[:page]
    @results = if @query.length >= 3
      Handbook.content_search(@query, locale: I18n.locale)
    else
      []
    end
  end
end
