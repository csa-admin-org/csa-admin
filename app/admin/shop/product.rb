ActiveAdmin.register Shop::Product do
  menu parent: :shop, priority: 4
  actions :all, except: [:show]

  breadcrumb do
    links = [t('active_admin.menu.shop')]
    unless params['action'] == 'index'
      links << link_to(Shop::Product.model_name.human(count: 2), shop_products_path)
    end
    links
  end

  scope :available, default: true
  scope :unavailable

  filter :name_contains,
    label: -> { Shop::Product.human_attribute_name(:name) },
    as: :string
  filter :tags,
    as: :select,
    collection: -> { Shop::Tag.all }
  filter :producer,
    as: :select,
    collection: -> { Shop::Producer.order(:name) }
  filter :variant_name_contains,
    label: -> { Shop::ProductVariant.model_name.human(count: 1) },
    as: :string
  filter :price,
    label: -> { Shop::ProductVariant.human_attribute_name(:price) },
    as: :numeric
  filter :stock,
    label: -> { Shop::ProductVariant.human_attribute_name(:stock) },
    as: :numeric

  includes :variants

  index download_links: false do
    selectable_column
    column :name, ->(product) { auto_link product }, sortable: :names
    column Shop::ProductVariant.model_name.human(count: 2), ->(product) {
      display_variants(self, product)
    }
    actions class: 'col-actions-2'
  end

  csv do
    column(:name)
    column(:producer) { |p| p.producer&.name }
    column(:available)
    column(:created_at)
    column(:updated_at)
  end

  form do |f|
    if f.object.errors[:variants].present?
      ul class: 'errors' do
        f.object.errors.full_messages.each do |msg|
          li msg
        end
      end
    end
    f.inputs t('.details') do
      translated_input(f, :names, required: true)
      translated_input(f, :descriptions,
        as: :action_text,
        required: false)
      f.input :tags,
        as: :select,
        collection: Shop::Tag.all.map { |t| [t.display_name, t.id] },
        input_html: { multiple: true, id: 'select-tags' }
      f.input :producer
      f.input :available, as: :boolean, required: false
      f.has_many :variants, allow_destroy: true do |ff|
        translated_input(ff, :names, required: true)
        ff.input :price, as: :number, step: 0.05, min: 0, max: 99999.95
        ff.input :weight_in_kg, as: :number, step: 0.005, min: 0, required: false
        ff.input :stock, as: :number, step: 1, min: 0, required: false
      end
    end
    f.actions
  end

  permit_params(
    :producer_id,
    :available,
    *I18n.available_locales.map { |l| "name_#{l}" },
    *I18n.available_locales.map { |l| "description_#{l}" },
    tag_ids: [],
    variants_attributes: [
      :id,
      :price,
      :weight_in_kg,
      :stock,
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
  end

  config.sort_order = 'names_desc'
  config.per_page = 100
  config.batch_actions = true
end
