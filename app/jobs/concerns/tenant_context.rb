# frozen_string_literal: true

module TenantContext
  extend ActiveSupport::Concern

  included do
    around_perform do |job, block|
      job.with_context(&block)
    end
  end

  def serialize
    set_context(
      "tenant" => Tenant.current,
      "current" => Current.attributes)

    super
  end

  def with_context(&block)
    context = arguments.pop
    Tenant.switch(context["tenant"]) do
      Current.set(context["current"], &block)
    end
  ensure
    set_context(context)
  end

  private

  def set_context(context)
    return if context_set?(context)

    self.arguments << context
  end

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
