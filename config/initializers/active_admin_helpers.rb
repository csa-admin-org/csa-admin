# frozen_string_literal: true

ActiveAdmin.before_load do
  class ActiveAdmin::ResourceDSL
    include ActionView::Helpers::TranslationHelper
    include RailsIcons::Helpers::IconHelper
    include ApplicationHelper
    include ActivitiesHelper
  end
end
