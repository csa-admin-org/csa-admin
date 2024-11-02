# frozen_string_literal: true

Rails.application.config.to_prepare do
  module CurrentShardPatch
    # Force all SolidQueue::Record to use the queue shard instead of
    # the current tenant shard.
    # https://github.com/rails/solid_queue/issues/369#issuecomment-2453030860
    def current_shard; :queue end
  end

  SolidQueue::Record.send(:extend, CurrentShardPatch)
end
