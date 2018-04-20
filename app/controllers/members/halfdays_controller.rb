class Members::HalfdaysController < Members::ApplicationController
  skip_before_action :authenticate_member!

  # GET /halfdays.rss
  def index
    @halfdays = Halfday.available(limit: 10)
    respond_to do |format|
      format.rss
    end
  end
end
