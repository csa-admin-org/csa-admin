module HasNote
  extend ActiveSupport::Concern

  included do
    scope :with_note, ->(bool) {
      if bool == 'true'
        where.not(note: [nil, ''])
      else
        where(note: [nil, ''])
      end
    }
  end

  def note=(note)
    super note.presence
  end
end
