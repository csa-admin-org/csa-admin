# frozen_string_literal: true

# Shared configuration for audit index pages.
#
# This module extracts common behavior from the model-specific audit admin
# resources (MemberAudit, MembershipAudit, DeliveryCycleAudit) to reduce
# duplication while still allowing each resource to customize its breadcrumbs.
#
# Usage:
#   ActiveAdmin.register Audit, as: "ModelAudit" do
#     extend AuditsIndex
#     audits_for Model
#
#     breadcrumb do
#       # Custom breadcrumb for this model
#     end
#   end
#
# Note: We use `extend` instead of `include` because ActiveAdmin's register
# block runs in the context of a DSL object, not a class definition.
# See: https://tmichel.github.io/2015/02/22/sharing-code-between-activeadmin-resources/
#
module AuditsIndex
  def self.extended(base)
    base.instance_eval do
      menu false
      actions :index

      includes :session
      index title: -> { Audit.model_name.human(count: 2) },
            download_links: false,
            class: "table-auto",
            blank_slate_link: false,
            blank_slate_content: -> { I18n.t("audits.blank_slate") } do
        column :actor, ->(a) { link_with_session a.actor, a.session }
        column :changes, ->(a) {
          model_class = controller.auditable_model_class

          if a.metadata["new_config_from"].present?
            div class: "mb-3 text-sm text-gray-600 dark:text-gray-400" do
              span "#{model_class.human_attribute_name(:new_config_from)}: "
              strong l(a.metadata["new_config_from"].to_date, format: :medium)
            end
          end

          ul class: "space-y-4" do
            a.changes.each do |attr, change|
              next unless helpers.should_display_audit_change?(attr, change.first, change.last)

              li do
                h4 model_class.human_attribute_name(attr), class: "font-normal"
                div class: "flex items-center gap-3 text-sm" do
                  div class: "text-gray-500 dark:text-gray-400" do
                    text_node helpers.display_audit_change(model_class, attr, change.first)
                  end
                  div "→", class: "text-gray-400 dark:text-gray-500 shrink-0 text-xl"
                  div do
                    text_node helpers.display_audit_change(model_class, attr, change.last)
                  end
                end
              end
            end
          end
        }, class: "py-3"
        column :updated_at, ->(a) { l(a.updated_at, format: :short) }, class: "text-right whitespace-nowrap"
      end

      controller do
        def scoped_collection
          Audit
            .where(auditable: parent)
            .where(created_at: (parent.created_at + 1.second)..)
        end

        def auditable_model_class
          @auditable_model_class
        end

        def auditable_model_class=(klass)
          @auditable_model_class = klass
        end
      end

      config.sort_order = "updated_at_desc"
      config.per_page = 50
      config.filters = false
    end
  end

  # DSL method to configure which model this audit resource is for.
  # This sets up the belongs_to relationship and stores the model class
  # for use in rendering audit changes.
  def audits_for(model_class)
    parent_name = model_class.model_name.singular.to_sym

    belongs_to parent_name

    controller do
      define_method(:auditable_model_class) { model_class }
    end
  end
end
