# frozen_string_literal: true

ActiveAdmin.register Permission do
  menu false
  actions :all, except: [ :show ]

  breadcrumb do
    links = [ link_to(Admin.model_name.human(count: 2), admins_path) ]
    if params[:action] != "index"
      links << link_to(Permission.model_name.human(count: 2), permissions_path)
    end
    links
  end

  includes :admins
  index download_links: false do
    column :name, sortable: true
    column [ Permission.human_attribute_name(:rights), t("permissions.rights.write") ].join(" – "), ->(p) { display_rights(p) }
    column :admins, ->(p) {
      link_to p.admins_count, admins_path(q: { permission_id_eq: p.id }, scope: :all)
    }, class: "text-right"
    actions
  end

  form do |f|
    f.inputs t(".details") do
      translated_input(f, :names)
    end

    f.semantic_fields_for :rights do |fr|
      f.inputs Permission.human_attribute_name(:rights) do
        features = Permission.editable_features
        features.sort_by { |f| feature_name(f) }.each do |feature|
          fr.input feature,
            label: feature_name(feature),
            as: :select,
            prompt: true,
            include_blank: false,
            collection: permission_rights_collection(f.object, feature)
        end
      end
    end
    f.semantic_fields_for :rights do |fr|
      f.inputs Permission.human_attribute_name(:superadmin_rights) do
        Permission.superadmin_features.sort_by { |f| feature_name(f) }.each do |feature|
          fr.input feature,
            label: feature_name(feature),
            as: :select,
            input_html: { disabled: true },
            collection: [
              [
                t("permissions.rights.read"),
                :read,
                { selected: true }
              ]
            ]
        end
      end
    end
    f.actions
  end

  permit_params(
    *%i[default_right],
    *I18n.available_locales.map { |l| "name_#{l}" },
    *I18n.available_locales.map { |l| "description_#{l}" },
    rights: {})

  order_by(:name) do |clause|
    config
      .resource_class
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.filters = false
  config.sort_order = "name_asc"
end
