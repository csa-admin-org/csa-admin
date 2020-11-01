class Liquid::ACPDrop < Liquid::Drop
  def initialize(acp)
    @acp = acp
  end

  def name
    @acp.name
  end
end
