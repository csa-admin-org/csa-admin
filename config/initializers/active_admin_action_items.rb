# frozen_string_literal: true

# Customize ActiveAdmin default action items to add icons and include Audits link
ActiveAdmin.before_load do |app|
  module ActiveAdmin
    class Resource
      module ActionItems
        private

        # Override to insert Audits between Edit and Destroy
        def add_default_action_items
          add_default_new_action_item
          add_default_audits_action_item
          add_default_edit_action_item
          add_default_destroy_action_item
        end

        # Adds the default New link on index
        def add_default_new_action_item
          add_action_item :new, only: :index, if: -> { new_action_authorized?(active_admin_config.resource_class) } do
            localizer = ActiveAdmin::Localizers.resource(active_admin_config)
            action_link localizer.t(:new_model), new_resource_path, icon: "plus"
          end
        end

        # Adds the default Audits link on show (for auditable resources)
        # Placed between Edit and Destroy for logical grouping
        def add_default_audits_action_item
          add_action_item :audits, only: :show, if: -> {
            next false unless authorized?(:read, Audit)
            next false unless resource.respond_to?(:audits)

            # Only show if the audit route exists for this resource
            resource_name = resource.class.model_name.singular
            path_method = "#{resource_name}_#{resource_name}_audits_path"
            respond_to?(path_method, true)
          } do
            resource_name = resource.class.model_name.singular
            path_method = "#{resource_name}_#{resource_name}_audits_path"
            css_class = Audit.relevant_for(resource).none? ? "opacity-40 hover:opacity-100" : nil
            action_link nil, send(path_method, resource), icon: "history", title: Audit.model_name.human(count: 2), class: css_class
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
