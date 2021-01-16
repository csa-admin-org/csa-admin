class Liquid::AdminDepotDrop < Liquid::Drop
  def initialize(depot)
    @depot = depot
  end

  def id
    @depot.id
  end

  def name
    @depot.name
  end

  def type
    Depot.model_name.human
  end

  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .depot_url(@depot.id, {}, host: Current.acp.email_default_host)
  end
end
