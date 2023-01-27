ActiveAdmin.register GroupBuying::Product do
  menu parent: :group_buying, priority: 3
  actions :all, except: [:show]

  breadcrumb do
    if params[:action] == 'new'
      [
        t('active_admin.menu.group_buying'),
        link_to(GroupBuying::Product.model_name.human(count: 2), group_buying_products_path)
      ]
    elsif params['action'] == 'index'
        [t('active_admin.menu.group_buying')]
    else
      links = [
        t('active_admin.menu.group_buying'),
        link_to(GroupBuying::Producer.model_name.human(count: 2), group_buying_producers_path),
        group_buying_product.producer.name,
        link_to(
          GroupBuying::Product.model_name.human(count: 2),
          group_buying_products_path(q: { producer_id_eq: group_buying_product.producer_id }, scope: :all))
      ]
      if params['action'].in? %W[edit]
        links << group_buying_product.name
      end
      links
    end
  end

  filter :producer,
    as: :select,
    collection: -> { GroupBuying::Producer.order(:name) }
  filter :available
  filter :price

  includes :producer, :order_items

  index do
    selectable_column
    column :name, ->(product) { auto_link product }, sortable: :names
    column :available, ->(product) { status_tag(product.available? ? :yes : :no) }
    column :price, ->(product) { cur(product.price) }
    if authorized?(:update, GroupBuying::Product)
      actions class: 'col-actions-2'
    end
  end

  sidebar_group_buying_deprecation_warning

  csv do
    column(:name)
    column(:producer) { |p| p.producer.name }
    column(:price) { |p| cur(p.price) }
    column(:available)
    column(:created_at)
    column(:updated_at)
  end

  form do |f|
    f.inputs t('.details') do
      f.input :producer
      translated_input(f, :names)
      translated_input(f, :descriptions, as: :action_text)
      f.input :price, as: :number, step: 0.05, min: -99999.95, max: 99999.95
      f.input :available, as: :boolean, required: false
    end
    f.actions
  end

  permit_params(
    :producer_id,
    :available,
    :price,
    *I18n.available_locales.map { |l| "name_#{l}" },
    *I18n.available_locales.map { |l| "description_#{l}" })

  batch_action :make_available do |selection|
    GroupBuying::Product.where(id: selection).update_all(available: true)
    redirect_back fallback_location: collection_path
  end

  batch_action :make_unavailable do |selection|
    GroupBuying::Product.where(id: selection).update_all(available: false)
    redirect_back fallback_location: collection_path
  end

  controller do
    include TranslatedCSVFilename
  end

  config.batch_actions = true
  config.sort_order = :default_scope
end
