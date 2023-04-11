ActiveAdmin.register Newsletter::Segment do
  menu false
  actions :all, except: [:show]

  breadcrumb do
    links = [link_to(Newsletter.model_name.human(count: 2), newsletters_path)]
    if params[:action] != 'index'
      links << link_to(Newsletter::Segment.model_name.human(count: 2), newsletter_segments_path)
    end
    links
  end

  sidebar :info do
    div class: 'content' do
      para t('newsletters.segment.info_html')
    end
  end

  index download_links: false do
    column :title, ->(s) { link_to s.title, [:edit, s] }, sortable: false
    column Member.model_name.human(count: 2) , ->(s) { s.members.count }, sortable: false
    actions defaults: true, class: 'col-actions-2'
  end

  form do |f|
    f.inputs do
      translated_input(f, :titles, required: true)
    end

    f.inputs t('newsletters.segment.criterias') do
      f.input :basket_size_ids,
        collection: BasketSize.all,
        as: :check_boxes,
        label: BasketSize.model_name.human(count: 2),
        hint: t('formtastic.hints.newsletter/segment.basket_size_ids')
      if BasketComplement.any?
        f.input :basket_complement_ids,
          collection: BasketComplement.all,
          as: :check_boxes,
          label: BasketComplement.model_name.human(count: 2),
          hint: t('formtastic.hints.newsletter/segment.basket_complement_ids')
      end
      f.input :depot_ids,
        collection: Depot.all,
        as: :check_boxes,
        label: Depot.model_name.human(count: 2),
        hint: t('formtastic.hints.newsletter/segment.depot_ids')
      if DeliveriesCycle.many?
        f.input :deliveries_cycle_ids,
          collection: DeliveriesCycle.all,
          as: :check_boxes,
          label: DeliveriesCycle.model_name.human(count: 2),
          hint: t('formtastic.hints.newsletter/segment.deliveries_cycle_ids')
      end
      f.input :first_membership,
        as: :select,
        collection: [[t('boolean.yes'), true], [t('boolean.no'), false]],
        include_blank: true,
        hint: t('formtastic.hints.newsletter/segment.first_membership')
      f.input :renewal_state,
        as: :select,
        collection: renewal_states_collection,
        include_blank: true
    end

    f.actions
  end

  permit_params(
    :renewal_state,
    :first_membership,
    *I18n.available_locales.map { |l| "title_#{l}" },
    basket_size_ids: [],
    basket_complement_ids: [],
    depot_ids: [],
    deliveries_cycle_ids: [])

  config.filters = false
  config.sort_order = :default_scope
end
