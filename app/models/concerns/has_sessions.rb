module HasSessions
  extend ActiveSupport::Concern

  included do
    has_many :sessions, dependent: :destroy
    has_one :last_session, -> { order('last_used_at DESC NULLS LAST') }, class_name: 'Session'
  end

  def last_session_used_at
    last_session&.last_used_at
  end
end
