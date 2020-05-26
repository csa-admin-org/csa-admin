ActiveAdmin.register BasketContent do
  menu priority: 5
  actions :all, except: [:show]

  filter :delivery, as: :select
  filter :vegetable, as: :select
  filter :basket_size, as: :select, collection: -> { [[small_basket.name, 'small'], [big_basket.name, 'big']] }
  filter :depots, as: :select

  includes :delivery, :vegetable, :depots
  index download_links: -> {
    params.dig(:q, :delivery_id_eq) ? [:csv, :xlsx] : [:csv]
  } do
    column :date, ->(bc) { bc.delivery.date.to_s }
    column :vegetable, ->(bc) { bc.vegetable.name }
    column :quantity, ->(bc) { display_quantity(bc) }
    column small_basket.name, ->(bc) { display_basket_quantity(bc, :small) }
    column big_basket.name, ->(bc) { display_basket_quantity(bc, :big) }
    column :surplus, ->(bc) { display_surplus_quantity(bc) }
    column :depots, ->(bc) { display_depots(bc) }
    actions
  end

  csv do
    column(:date) { |bc| bc.delivery.date.to_s }
    column(:vegetable) { |bc| bc.vegetable.name }
    column(:quantity) { |bc| display_quantity(bc) }
    column(small_basket.name) { |bc| display_basket_quantity(bc, :small) }
    column(big_basket.name) { |bc| display_basket_quantity(bc, :big) }
    column(:surplus) { |bc| display_surplus_quantity(bc) }
    column(:depots) { |bc| display_depots(bc) }
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
        collection: BasketContent::UNITS,
        required: true,
        prompt: true
    end
    f.inputs Basket.model_name.human(count: 2) do
      f.input :basket_sizes,
        collection: [[small_basket.name, 'small'], [big_basket.name, 'big']],
        as: :check_boxes,
        label: false
      f.input :same_basket_quantities,
        as: :boolean,
        input_html: { disabled: !f.object.both_baskets? },
        label_class: f.object.both_baskets? ? '' : 'disabled'
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
    basket_sizes: [])

  before_action only: :index do
    if params.except(:subdomain, :controller, :action).empty?
      redirect_to q: { delivery_id_eq: Delivery.next&.id }, utf8: '✓'
    end
  end

  before_build do |basket_content|
    basket_content.delivery ||= Delivery.next
    if basket_content.basket_sizes.empty?
      basket_content.basket_sizes = BasketContent::SIZES
    end
    if basket_content.depots.empty?
      basket_content.depots = Depot.all
    end
  end

  before_action do
    unless BasketSize.paid.count == 2
      redirect_to basket_sizes_path, notice: t('active_admin.flash.two_paid_basket_required')
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
