class Liquid::ACPDrop < Liquid::Drop
  def initialize(acp)
    @acp = acp
  end

  def name
    @acp.name
  end

  def url
    @acp.url
  end

  def email
    @acp.email
  end

  def phone
    @acp.phone&.phony_formatted(normalize: @acp.country_code, format: :international)
  end

  def activity_phone
    @acp.activity_phone&.phony_formatted(normalize: @acp.country_code, format: :international)
  end
end
