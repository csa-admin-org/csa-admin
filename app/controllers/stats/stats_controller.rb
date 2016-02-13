class Stats::StatsController < Stats::ApplicationController
  # GET /:id
  def show
    @stats = Stats.all(params[:id])
  end
end
