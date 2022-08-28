
module CurrentContext
  extend ActiveSupport::Concern

  included do
    around_perform do |_, block|
      Current.set(@current, &block)
    end
  end

  def serialize
    super.merge(
      'tenant' => Tenant.current,
      'current' => ActiveJob::Arguments.serialize(Current.attributes))
  end

  def deserialize(data)
    Tenant.switch!(data['tenant'])
    @current = ActiveJob::Arguments.deserialize(data['current']).to_h
    super
  end
end
