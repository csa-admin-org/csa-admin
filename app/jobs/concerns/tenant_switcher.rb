# frozen_string_literal: true

module TenantSwitcher
  extend ActiveSupport::Concern

  included do
    around_perform do |job, block|
      begin
        context = job.arguments.pop
        Tenant.switch(context["tenant"]) do
          Current.set(context["current"], &block)
        end
      ensure
        job.set_context(context)
      end
    end
  end

  def serialize
    set_context(
      "tenant" => Tenant.current,
      "current" => Current.attributes)

    super
  end

  def set_context(context)
    return if context_set?(context)

    self.arguments << context
  end

  private

  def context_set?(context)
    last_argument = self.arguments&.last
    return unless last_argument.is_a?(Hash)

    last_argument.keys.sort == context.keys.sort
  end

  # Argument deserialization is done before the around_perform block is executed,
  # so we need to ensure that the tenant context is set when deserializing the arguments.
  def deserialize_arguments(serialized_args)
    context = serialized_args.last
    Tenant.switch(context["tenant"]) { super }
  end
end
