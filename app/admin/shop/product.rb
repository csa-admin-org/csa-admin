ActiveAdmin.register Shop::Product do
  menu parent: :shop, priority: 2
  actions :all, except: [:show]

  breadcrumb do
    if params['action'] == 'index'
      [t('active_admin.menu.shop')]
    else
      links = [
        t('active_admin.menu.shop'),
        link_to(Shop::Product.model_name.human(count: 2), shop_products_path)
      ]
      if params['action'].in? %W[edit]
        links << shop_product.name
      end
      links
    end
  end

  scope :all
  scope :available, default: true
  scope :unavailable

  filter :name_cont,
    label: -> { Shop::Product.human_attribute_name(:name) },
    as: :string
  filter :tags,
    as: :select,
    collection: -> { Shop::Tag.all }
  filter :producer, as: :select
  filter :depot, as: :select, collection: -> { Depot.all }
  filter :delivery, as: :select, collection: -> { Delivery.coming.shop_open.all }
  filter :variant_name_cont,
    label: -> { Shop::ProductVariant.model_name.human(count: 1) },
    as: :string
  filter :price,
    label: -> { Shop::ProductVariant.human_attribute_name(:price) },
    as: :numeric
  filter :stock,
    label: -> { Shop::ProductVariant.human_attribute_name(:stock) },
    as: :numeric

  includes :variants, :basket_complement
  index do
    selectable_column
    column :name, ->(product) { auto_link product }, sortable: :names
    column Shop::ProductVariant.model_name.human(count: 2), ->(product) {
      display_variants(self, product)
    }
    if authorized?(:update, Shop::Product)
      actions class: 'col-actions-2'
    end
  end

  action_item :tags, only: :index do
    link_to Shop::Tag.model_name.human(count: 2), shop_tags_path
  end

  csv do
    column(:id)
    column(:producer) { |p| p.producer&.name }
    column(:name)
    column(:basket_complement) { |p| p.basket_complement&.name }
    column(:product_variant)  { |p| p[:variant_name] }
    column(:price) { |p| p['variant_price'] }
    column(:weight_in_kg) { |p| p['variant_weight_in_kg'] }
    column(:stock) { |p| p['variant_stock'] }
    column(:available)
  end

  sidebar_shop_admin_only_warning
  sidebar_handbook_link('shop#produits')

  form do |f|
    f.semantic_errors :base
    errors_on(self, f, :variants)
    tabs do
      tab t('.details') do
        f.inputs nil do
          translated_input(f, :names)
          translated_input(f, :descriptions, as: :action_text)
          f.input :tags,
            as: :select,
            collection: Shop::Tag.all.map { |t| [t.display_name, t.id] },
            wrapper_html: { class: 'select-tags' },
            input_html: { multiple: true, data: { controller: 'select-tags' } }
          f.input :producer
          f.input :basket_complement,
            collection: BasketComplement.includes(:shop_product).map { |bc|
              [bc.name, bc.id, disabled: !!bc.shop_product && bc.shop_product != f.object]
            },
            hint: t('formtastic.hints.shop/product.basket_complement')
          f.input :display_in_delivery_sheets,
            as: :boolean,
            input_html: { disabled: f.object.basket_complement_id? },
            hint: t('formtastic.hints.shop/product.display_in_delivery_sheets')
        end
      end
      tab t('.availability'), id: :availability do
        f.inputs nil, 'data-controller' => 'form-checkbox-toggler' do
          f.input :available,
            as: :boolean,
            required: false,
            input_html: { data: {
              form_checkbox_toggler_target: 'checkbox',
              action: 'form-checkbox-toggler#toggleInput'
            } }
          f.input :available_for_depot_ids,
            label: Depot.model_name.human(count: 2),
            as: :check_boxes,
            collection: Depot.all,
            input_html: {
              data: { form_checkbox_toggler_target: 'input' }
            }
          coming_deliveries = Delivery.coming.shop_open.all
          if coming_deliveries.any?
            f.input :available_for_delivery_ids,
              label: Delivery.model_name.human(count: 2),
              as: :check_boxes,
              collection: coming_deliveries,
              input_html: {
                data: { form_checkbox_toggler_target: 'input' }
              }
          end
        end
      end
      tab Shop::ProductVariant.model_name.human(count: 2), id: :variants do
        f.inputs nil do
          f.has_many :variants, allow_destroy: -> (pv) { pv.can_destroy? }, heading: nil do |ff|
            translated_input(ff, :names)
            ff.input :price, as: :number, step: 0.05, min: 0, max: 99999.95
            ff.input :weight_in_kg, as: :number, step: 0.005, min: 0, required: false
            ff.input :stock, as: :number, step: 1, min: 0, required: false
            ff.input :available, as: :boolean, required: false
          end
        end
      end
    end
    f.actions
  end

  permit_params(
    :producer_id,
    :basket_complement_id,
    :available,
    :display_in_delivery_sheets,
    *I18n.available_locales.map { |l| "name_#{l}" },
    *I18n.available_locales.map { |l| "description_#{l}" },
    tag_ids: [],
    available_for_depot_ids: [],
    available_for_delivery_ids: [],
    variants_attributes: [
      :id,
      :price,
      :weight_in_kg,
      :stock,
      :available,
      :_destroy,
      *I18n.available_locales.map { |l| "name_#{l}" }
    ])

  before_build do |product|
    if params[:action] == 'new'
      product.available ||= true
      product.variants << Shop::ProductVariant.new if product.variants.none?
    end
  end

  batch_action :make_available, if: ->(attr) { params[:scope] == 'unavailable' } do |selection|
    Shop::Product.where(id: selection).update_all(available: true)
    redirect_back fallback_location: collection_path
  end

  batch_action :make_unavailable, if: ->(attr) { !params[:scope] || params[:scope] == 'available' } do |selection|
    Shop::Product.where(id: selection).update_all(available: false)
    redirect_back fallback_location: collection_path
  end

  controller do
    include TranslatedCSVFilename
    include ShopHelper

    def find_collection(options = {})
      collection = super
      if params[:format] == 'csv'
        collection = collection.left_joins(:variants).select(<<-SQL)
          shop_products.*,
          shop_product_variants.names->>'#{I18n.locale}' as variant_name,
          shop_product_variants.price as variant_price,
          shop_product_variants.weight_in_kg as variant_weight_in_kg,
          shop_product_variants.stock as variant_stock
        SQL
      end
      collection
    end
  end

  config.batch_actions = true
  config.sort_order = :default_scope
end
