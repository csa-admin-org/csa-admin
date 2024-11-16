# frozen_string_literal: true

module TenantSwitcher
  extend ActiveSupport::Concern

  included do
    around_perform do |job, block|
      Tenant.switch(@tenant) do
        current_attrs = job.arguments.pop
        Current.set(current_attrs, &block)
      end
    end
  end

  private

  def serialize_arguments(arguments)
    arguments << Current.attributes
    arguments << Tenant.current
    # We need to set this instance to avoid serializing multiple times,
    # and then adding the extra arguments each time.
    # See: https://github.com/rails/rails/blob/main/activejob/lib/active_job/core.rb#L175
    @serialized_arguments = super(arguments)
  end

  def deserialize_arguments(serialized_args)
    @tenant = serialized_args.pop
    Tenant.switch(@tenant) { super(serialized_args) }
  end
end
