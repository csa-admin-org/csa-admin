# frozen_string_literal: true

Rails.application.configure do
  config.lograge.base_controller_class = [
    "ActionController::Base",
    "ActiveAdmin::BaseController"
  ]

  config.lograge.custom_payload do |controller|
    payload = {
      host: controller.request.host
    }
    payload[:org] = Tenant.current if Tenant.inside?
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
    options[:org] = Tenant.current if Tenant.inside?
    options[:params] = event.payload[:params].except(:controller, :action, :format, :id)
    options
  end

  config.lograge.ignore_actions = [ "Rails::HealthController#show" ]
end
