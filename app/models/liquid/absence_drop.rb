# frozen_string_literal: true

class Liquid::AbsenceDrop < Liquid::Drop
  def initialize(absence)
    @absence = absence
  end

  def start_date
    I18n.l(@absence.started_on)
  end

  def end_date
    I18n.l(@absence.ended_on)
  end

  def note
    @absence.note.presence
  end

  def baskets_count
    @absence.baskets.size
  end
end
