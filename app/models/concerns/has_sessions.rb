module HasSessions
  extend ActiveSupport::Concern

  included do
    has_many :sessions
    has_one :last_session, -> { order(created_at: :desc) }, class_name: 'Session'
  end

  def last_session_used_at
    last_session&.last_used_at
  end
end
