class PostmarkMockClient
  include Singleton

  attr_accessor :dump_suppressions_response
  attr_reader :calls

  def initialize
    reset!
  end

  def reset!
    @dump_suppressions_response = []
    @calls = []
  end

  def dump_suppressions(stream_id, options = {})
    @calls << [:dump_suppressions, stream_id, options]
    @dump_suppressions_response
  end

  def delete_suppressions(stream_id, email)
    @calls << [:delete_suppressions, stream_id, email]
  end

  def create_suppressions(stream_id, email)
    @calls << [:create_suppressions, stream_id, email]
  end
end
