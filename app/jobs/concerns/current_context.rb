module CurrentContext
  extend ActiveSupport::Concern

  included do
    around_perform do |_, block|
      Tenant.switch(@tenant) do
        attrs = ActiveJob::Arguments.deserialize(@current).to_h
        Current.set(attrs, &block)
      end
    end
  end

  def serialize
    super.merge(
      "tenant" => Tenant.current,
      "current" => ActiveJob::Arguments.serialize(Current.attributes))
  end

  def deserialize(data)
    @tenant = data["tenant"]
    @current = data["current"]
    super
  end

  private

  def deserialize_arguments(arguments)
    Tenant.switch(@tenant) { super }
  end
end
