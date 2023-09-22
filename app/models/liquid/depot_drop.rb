class Liquid::DepotDrop < Liquid::Drop
  def initialize(depot)
    @depot = depot
  end

  def id
    @depot.id
  end

  def name
    @depot.public_name
  end

  def member_note
    @depot.public_note&.html_safe.presence
  end
end
