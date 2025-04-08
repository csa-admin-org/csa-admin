# frozen_string_literal: true

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
    @depot.public_note_as_plain_text.presence
  end
end
