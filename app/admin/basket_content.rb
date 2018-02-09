ActiveAdmin.register BasketContent do
  menu priority: 5
  actions :all, except: [:show]

  includes :delivery, :vegetable, :distributions
  index do
    column :date, ->(bc) { bc.delivery.date.to_s }
    column :vegetable, ->(bc) { bc.vegetable.name }
    column :quantity, ->(bc) { display_quantity(bc) }
    column 'Eveil', ->(bc) { display_basket_quantity(bc, :small) }
    column 'Abondance', ->(bc) { display_basket_quantity(bc, :big) }
    column 'Perte', ->(bc) { display_lost_quantity(bc) }
    column :distributions, ->(bc) { display_distributions(bc) }
    actions
  end

  csv do
    column(:date) { |bc| bc.delivery.date.to_s }
    column(:vegetable) { |bc| bc.vegetable.name }
    column(:quantity) { |bc| display_quantity(bc) }
    column('Eveil') { |bc| display_basket_quantity(bc, :small) }
    column('Abondance') { |bc| display_basket_quantity(bc, :big) }
    column('Perte') { |bc| display_lost_quantity(bc) }
    column(:distributions) { |bc| display_distributions(bc) }
  end

  form do |f|
    f.inputs do
      f.input :delivery,
        collection: Delivery.all,
        include_blank: false
    end
    f.inputs 'Contenu' do
      f.input :vegetable,
        collection: Vegetable.all,
        include_blank: false
      f.input :quantity
      f.input :unit,
        collection: BasketContent::UNITS,
        include_blank: false
    end
    f.inputs 'Paniers' do
      f.input :basket_sizes,
        collection: [['Eveil', 'small'], ['Abondance', 'big']],
        as: :check_boxes,
        label: false
      f.input :same_basket_quantities,
        as: :boolean,
        input_html: { disabled: !f.object.both_baskets? }
    end
    f.inputs 'Distributions' do
      f.input :distributions,
        collection: Distribution.all,
        as: :check_boxes,
        label: false
    end
    f.actions
  end

  filter :delivery, as: :select
  filter :vegetable, as: :select
  filter :basket_size, as: :select, collection: [['Eveil', 'small'], ['Abondance', 'big']]
  filter :distributions, as: :select

  before_action only: :index do
    if params['commit'].blank? && request.format.html?
      params['q'] = {
        delivery_id_eq: Delivery.next&.id,
      }
    end
  end

  before_build do |basket_content|
    basket_content.delivery ||= Delivery.next
    if basket_content.basket_sizes.empty?
      basket_content.basket_sizes = BasketContent::SIZES
    end
    if basket_content.distributions.empty?
      basket_content.distributions = Distribution.all
    end
  end

  controller do
    def create
      super do |format|
        redirect_to collection_url and return if resource.valid?
      end
    end

    def update
      super do |format|
        redirect_to collection_url and return if resource.valid?
      end
    end
  end

  permit_params *%i[
    delivery_id
    vegetable_id
    quantity
    same_basket_quantities
    unit
  ],
    distribution_ids: [],
    basket_sizes: []
end
