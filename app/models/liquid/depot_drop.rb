class Liquid::DepotDrop < Liquid::Drop
  def initialize(depot)
    @depot = depot
  end

  def name
    @depot.name
  end
end
