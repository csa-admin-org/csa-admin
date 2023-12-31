ActiveAdmin.register DepotGroup do
  menu false
  actions :all, except: [:show]

  breadcrumb do
    links = [link_to(Depot.model_name.human(count: 2), depots_path)]
    if params[:action] != 'index'
      links << link_to(DepotGroup.model_name.human(count: 2), depots_path)
    end
    if params['action'].in? %W[edit]
      links << auto_link(resource)
    end
    links
  end

  includes :depots
  index download_links: false do
    column :name, ->(dg) { display_name_with_public_name(dg) }
    column :depots, ->(dg) { dg.depots.reorder(:name).map { |d| auto_link d }.to_sentence.html_safe }
    actions class: 'col-actions-2'
  end

  form do |f|
    f.inputs do
      translated_input(f, :names, required: true)
      translated_input(f, :public_names,
        required: false,
        hint: t('formtastic.hints.depot_group.public_name'))
    end

    f.inputs t('active_admin.resource.show.member_new_form') do
      translated_input(f, :information_texts,
        as: :action_text,
        required: false,
        hint: t('formtastic.hints.depot_group.information_text'))

      f.input :member_order_priority,
        collection: member_order_priorities_collection,
        as: :select,
        prompt: true
    end

    f.inputs do
      other_group_ids = DepotGroup.pluck(:id) - [f.object.id]
      f.input :depots,
        collection: Depot.reorder(:name),
        as: :check_boxes
    end

    f.actions
  end

  permit_params(
    *%i[
      member_order_priority
    ],
    *I18n.available_locales.map { |l| "name_#{l}" },
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "information_text_#{l}" },
    depot_ids: [])


  config.sort_order = :default_scope
  config.paginate = false
  config.filters = false
end
