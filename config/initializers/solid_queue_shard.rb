# frozen_string_literal: true

Rails.application.config.to_prepare do
  # Only force the queue shard when this environment actually configures it
  # (production). Test/dev use the tenant primary DB / :test adapter and have
  # no `queue` entry in database.yml — patching them breaks schema checks.
  queue_configured = ActiveRecord::Base.configurations
    .configs_for(env_name: Rails.env, include_hidden: true)
    .any? { |c| c.name.to_s == "queue" }

  if queue_configured
    module CurrentShardPatch
      # Force all SolidQueue::Record to use the queue shard instead of
      # the current tenant shard.
      # https://github.com/rails/solid_queue/issues/369#issuecomment-2453030860
      def current_shard; :queue end
    end

    SolidQueue::Record.send(:extend, CurrentShardPatch)
  end
end
