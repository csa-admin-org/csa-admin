ActiveAdmin.register BasketContent do
  menu priority: 5
  actions :all, except: [:show]

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
      f.input :basket_types,
        collection: [['Eveil', 'small'], ['Abondance', 'big']],
        as: :check_boxes,
        label: false
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
  filter :basket, as: :select, collection: [['Eveil', 'small'], ['Abondance', 'big']]
  filter :distributions, as: :select

  before_filter only: :index do
    if params['commit'].blank?
      params['q'] = {
        delivery_id_eq: Delivery.coming.first&.id,
      }
    end
  end

  controller do
    def build_resource
      super
      resource.delivery ||= Delivery.coming.first
      if resource.basket_types.empty?
        resource.basket_types = Basket::TYPES.map(&:to_s)
      end
      if resource.distributions.empty?
        resource.distributions = Distribution.all
      end
      resource
    end

    def scoped_collection
      BasketContent.includes(:delivery, :vegetable, :distributions)
    end

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
    unit
  ],
    distribution_ids: [],
    basket_types: []
end
