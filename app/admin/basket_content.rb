ActiveAdmin.register BasketContent do
  menu priority: 5
  actions :all, except: [:show]

  includes :delivery, :vegetable, :depots
  index do
    column :date, ->(bc) { bc.delivery.date.to_s }
    column :vegetable, ->(bc) { bc.vegetable.name }
    column :quantity, ->(bc) { display_quantity(bc) }
    column small_basket.name, ->(bc) { display_basket_quantity(bc, :small) }
    column big_basket.name, ->(bc) { display_basket_quantity(bc, :big) }
    column :loses, ->(bc) { display_lost_quantity(bc) }
    column :depots, ->(bc) { display_depots(bc) }
    actions
  end

  csv do
    column(:date) { |bc| bc.delivery.date.to_s }
    column(:vegetable) { |bc| bc.vegetable.name }
    column(:quantity) { |bc| display_quantity(bc) }
    column(small_basket.name) { |bc| display_basket_quantity(bc, :small) }
    column(big_basket.name) { |bc| display_basket_quantity(bc, :big) }
    column(:loses) { |bc| display_lost_quantity(bc) }
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
        input_html: { disabled: !f.object.both_baskets? }
    end
    f.inputs Depot.model_name.human(count: 2) do
      f.input :depots,
        collection: Depot.all,
        as: :check_boxes,
        label: false
    end
    f.actions
  end

  filter :delivery, as: :select
  filter :vegetable, as: :select
  filter :basket_size, as: :select, collection: -> { [[small_basket.name, 'small'], [big_basket.name, 'big']] }
  filter :depots, as: :select

  before_action only: :index do
    if params['commit'].blank? && request.format.html?
      params['q'] = {
        delivery_id_eq: Delivery.next&.id
      }
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

  permit_params(*%i[
    delivery_id
    vegetable_id
    quantity
    same_basket_quantities
    unit
  ],
    depot_ids: [],
    basket_sizes: [])
end
