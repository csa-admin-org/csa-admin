# frozen_string_literal: true

ActiveAdmin.before_load do
  class ActiveAdmin::ResourceDSL
    include ActionView::Helpers::TranslationHelper
    include Rails.application.routes.url_helpers
    include IconsHelper
    include ApplicationHelper
    include ActivitiesHelper
    include TablesHelper
  end
end
ActiveAdmin.after_load do
  class ActiveAdmin::ResourceDSL
  end
end
