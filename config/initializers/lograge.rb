Rails.application.configure do
  config.lograge.base_controller_class = [
    'ActionController::Base',
    'ActiveAdmin::BaseController'
  ]

  config.lograge.custom_payload do |controller|
    payload = {
      host: controller.request.host
    }
    if controller.respond_to?(:current_admin, true) && controller.send(:current_admin)
      payload[:admin_id] = controller.send(:current_admin)&.id
    end
    if controller.respond_to?(:current_member, true) && controller.send(:current_member)
      payload[:member_id] = controller.send(:current_member)&.id
    end
    payload
  end

  config.lograge.custom_options = lambda do |event|
    options = {}
    unless Apartment::Tenant.current == 'public'
      options[:acp] = Apartment::Tenant.current
    end
    options
  end
end
