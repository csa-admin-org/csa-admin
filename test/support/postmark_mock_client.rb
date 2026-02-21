# frozen_string_literal: true

class PostmarkMockClient
  include Singleton

  attr_accessor :dump_suppressions_response,
    :get_message_responses,
    :get_bounce_responses
  attr_reader :calls

  def initialize
    reset!
  end

  def reset!
    @dump_suppressions_response = []
    @get_message_responses = {}
    @get_bounce_responses = {}
    @calls = []
  end

  def dump_suppressions(stream_id, options = {})
    @calls << [ :dump_suppressions, stream_id, options ]
    @dump_suppressions_response
  end

  def delete_suppressions(stream_id, email)
    @calls << [ :delete_suppressions, stream_id, email ]
  end

  def create_suppressions(stream_id, email)
    @calls << [ :create_suppressions, stream_id, email ]
  end

  def get_message(message_id)
    @calls << [ :get_message, message_id ]
    @get_message_responses[message_id] || { status: "Sent", message_events: [] }
  end

  def get_bounce(bounce_id)
    @calls << [ :get_bounce, bounce_id ]
    @get_bounce_responses[bounce_id] || {}
  end
end
