# frozen_string_literal: true

module DemoPageVisitTracking
  extend ActiveSupport::Concern

  IGNORED_CONTROLLER_PATHS = %w[
    demo/registrations
    favicons
    handbook_search
    search
    sessions
  ].freeze

  included do
    after_action :track_demo_page_visit
  end

  private

  def track_demo_page_visit
    return unless track_demo_page_visit?

    Demo::PageVisit.create!(
      admin: current_admin,
      session: current_session,
      path: request.path,
      controller_name: controller_path,
      action_name: action_name,
      page_key: Demo::PageVisit.page_key_for(controller_path, action_name),
      status: response.status)
  end

  def track_demo_page_visit?
    Tenant.demo? &&
      current_admin &&
      current_session&.admin_id == current_admin.id &&
      request.host == Tenant.admin_host &&
      request.get? &&
      request.format.html? &&
      response.successful? &&
      !ignored_demo_page_visit_controller?
  end

  def ignored_demo_page_visit_controller?
    IGNORED_CONTROLLER_PATHS.include?(controller_path) ||
      controller_path.start_with?("active_storage/")
  end
end
