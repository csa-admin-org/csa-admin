ActiveAdmin.register BasketContent do
  menu priority: 5
  actions :all, except: [:show]

  filter :delivery, as: :select
  filter :vegetable, as: :select
  filter :basket_size, as: :select, collection: -> { BasketSize.paid.reorder(:price) }
  filter :depots, as: :select

  includes :depots, :delivery, :vegetable
  index download_links: -> {
    params.dig(:q, :delivery_id_eq) ? [:csv, :xlsx] : [:csv]
  } do
    column :date, ->(bc) { bc.delivery.date.to_s }, class: 'nowrap'
    column :vegetable, ->(bc) { bc.vegetable.name }
    column :qt, ->(bc) { display_quantity(bc.quantity, bc.unit) }
    BasketSize.paid.reorder(:price).each do |basket_size|
      column basket_size.name, ->(bc) { display_basket_quantity(bc, basket_size) }, class: 'nowrap'
    end
    column :surplus, ->(bc) { display_surplus_quantity(bc) }
    all_depots = Depot.all.to_a
    column :depots, ->(bc) { display_depots(bc, all_depots) }
    actions class: 'col-actions-2'
  end

  csv do
    column(:date) { |bc| bc.delivery.date.to_s }
    column(:vegetable) { |bc| bc.vegetable.name }
    column(:unit) { |bc| t("units.#{bc.unit}") }
    column(:quantity) { |bc| bc.quantity }
    BasketSize.paid.reorder(:price).each do |basket_size|
      column("#{basket_size.name} - #{Basket.model_name.human(count: 2)}") { |bc|
        bc.baskets_count(basket_size)
      }
      column("#{basket_size.name} - #{BasketContent.human_attribute_name(:quantity)}") { |bc|
        bc.basket_quantity(basket_size)
      }
    end
    column(:surplus) { |bc| bc.surplus_quantity }
    all_depots = Depot.all.to_a
    column(:depots) { |bc| display_depots(bc, all_depots) }
  end

  form do |f|
    f.inputs do
      f.input :delivery,
        collection: Delivery.all,
        required: true,
        prompt: true
    end
    f.inputs BasketContent.human_attribute_name(:content) do
      f.input :vegetable,
        collection: Vegetable.all,
        required: true,
        prompt: true
      f.input :quantity
      f.input :unit,
        collection: units_collection,
        required: true,
        prompt: true
    end
    f.inputs Basket.model_name.human(count: 2) do
      f.input :basket_size_ids,
        collection: BasketSize.paid.reorder(:price),
        as: :check_boxes,
        label: false
      f.input :same_basket_quantities,
        as: :boolean,
        input_html: { disabled: !f.object.basket_size_ids.many? },
        label_class: f.object.basket_size_ids.many? ? '' : 'disabled'
    end
    f.inputs Depot.model_name.human(count: 2) do
      f.input :depots,
        collection: Depot.all,
        as: :check_boxes,
        label: false
    end
    f.actions
  end

  permit_params(*%i[
    delivery_id
    vegetable_id
    quantity
    same_basket_quantities
    unit
  ],
    depot_ids: [],
    basket_size_ids: [])

  before_action only: :index do
    if params.except(:subdomain, :controller, :action).empty?
      redirect_to q: { delivery_id_eq: Delivery.next&.id }, utf8: '✓'
    end
  end

  before_build do |basket_content|
    basket_content.delivery ||= Delivery.next
    if basket_content.basket_size_ids.empty?
      basket_content.basket_size_ids = BasketSize.paid.pluck(:id)
    end
    if basket_content.depots.empty?
      basket_content.depots = Depot.all
    end
  end

  controller do
    include TranslatedCSVFilename

    def index
      super do |format|
        format.xlsx do
          delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
          xlsx = XLSX::BasketContent.new(delivery)
          send_data xlsx.data,
            content_type: xlsx.content_type,
            filename: xlsx.filename
        end
      end
    end

    def collection
      super
        .joins(:delivery, :vegetable)
        .merge(Delivery.reorder(date: :desc))
        .merge(Vegetable.order_by_name)
    end

    def update
      super do
        redirect_to basket_contents_path(q: { delivery_id_eq: resource.delivery_id }) and return if resource.valid?
      end
    end

    def create
      super do
        redirect_to basket_contents_path(q: { delivery_id_eq: resource.delivery_id }) and return if resource.valid?
      end
    end
  end
end
