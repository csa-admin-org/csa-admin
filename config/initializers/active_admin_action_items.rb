# frozen_string_literal: true

# Add filters stimulus controller for live fitlering
ActiveAdmin.before_load do |app|
  module ActiveAdmin
    class Resource
      module ActionItems
        private

        # Adds the default New link on index
        def add_default_new_action_item
          add_action_item :new, only: :index, if: -> { new_action_authorized?(active_admin_config.resource_class) } do
            localizer = ActiveAdmin::Localizers.resource(active_admin_config)
            action_link localizer.t(:new_model), new_resource_path, icon: "plus"
          end
        end

        # Adds the default Edit link on show
        def add_default_edit_action_item
          add_action_item :edit, only: :show, if: -> { edit_action_authorized?(resource) } do
            localizer = ActiveAdmin::Localizers.resource(active_admin_config)
            action_link localizer.t(:edit_model), edit_resource_path(resource), icon: "pencil-square"
          end
        end

        # Adds the default Destroy link on show
        def add_default_destroy_action_item
          add_action_item :destroy, only: :show, if: -> { destroy_action_authorized?(resource) } do
            localizer = ActiveAdmin::Localizers.resource(active_admin_config)
            action_button \
              localizer.t(:delete_model),
              resource_path(resource),
              method: :delete,
              class: "destructive",
              icon: "trash"
          end
        end
      end
    end
  end
end
