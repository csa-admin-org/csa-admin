ActiveAdmin.register BasketContent do
  menu priority: 5
  actions :all, except: [:show]

  filter :delivery, as: :select
  filter :product, as: :select
  filter :basket_size, as: :select, collection: -> { BasketSize.paid }
  filter :depots, as: :select

  includes :depots, :delivery, :product, :basketcontents_depots

  class BasketContentIndex < ActiveAdmin::Views::IndexAsTable
    def build(_page_presenter, collection)
      if params.dig(:q, :delivery_id_eq).present? && collection.with_unit_price.any?
        delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
        panel t('.basket_prices', currency: currency_symbol), class: 'basket_prices' do
          render partial: 'active_admin/basket_contents/prices', locals: { delivery: delivery, context: self }
        end
      end
      super
    end
  end

  index as: BasketContentIndex, download_links: -> {
    params.dig(:q, :delivery_id_eq) ? [:csv, :xlsx] : [:csv]
  }, title: -> {
    title = BasketContent.model_name.human(count: 2)
    if params.dig(:q, :delivery_id_eq).present?
      delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
      title += " – #{l(delivery.date)}"
    end
    title
  } do
    unless params.dig(:q, :delivery_id_eq).present?
      column :delivery, ->(bc) { I18n.l bc.delivery.date, format: :number }, class: 'nowrap'
    end
    column :product, ->(bc) {
      display_with_unit_price(bc.unit_price, bc.unit) {
        display_with_external_url(bc.product.name, bc.product.url)
      }
    }
    column :qt, ->(bc) {
      display_with_price(bc.unit_price, bc.quantity) {
        display_quantity(bc.quantity, bc.unit)
      }
    }
    BasketSize.paid.each do |basket_size|
      column basket_size.name, ->(bc) {
        display_with_price(bc.unit_price, bc.basket_quantity(basket_size)) {
          display_basket_quantity(bc, basket_size)
        }
      }, class: 'nowrap'
    end
    column :surplus, ->(bc) {
      display_with_price(bc.unit_price, bc.surplus_quantity) {
        display_surplus_quantity(bc)
      }
    }
    all_depots = Depot.all.to_a
    column :depots, ->(bc) { display_depots(bc, all_depots) }
    if authorized?(:update, BasketContent)
      actions class: 'col-actions-2'
    end
  end

  action_item :product, only: :index do
    link_to BasketContent::Product.model_name.human(count: 2), basket_content_products_path
  end

  csv do
    column(:date) { |bc| bc.delivery.date.to_s }
    column(:product) { |bc| bc.product.name }
    column(:unit) { |bc| t("units.#{bc.unit}") }
    column(:unit_price) { |bc| cur(bc.unit_price) }
    column(:quantity) { |bc| bc.quantity }
    BasketSize.paid.each do |basket_size|
      column("#{basket_size.name} - #{Basket.model_name.human(count: 2)}") { |bc|
        bc.baskets_count(basket_size)
      }
      column("#{basket_size.name} - #{BasketContent.human_attribute_name(:quantity)}") { |bc|
        bc.basket_quantity(basket_size)
      }
      column("#{basket_size.name} - #{BasketContent.human_attribute_name(:price)}") { |bc|
        display_price bc.unit_price, bc.basket_quantity(basket_size)
      }
    end
    column(:surplus) { |bc| bc.surplus_quantity }
    column("#{BasketContent.human_attribute_name(:surplus)} - #{BasketContent.human_attribute_name(:price)}") { |bc|
      display_price bc.unit_price, bc.surplus_quantity
    }
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
    f.inputs BasketContent.human_attribute_name(:content), 'data-controller' => 'basket-content-products-select' do
      f.input :product,
        input_html: {
          data: {
            action: 'basket-content-products-select#productChange form-hint-url#change',
            'basket-content-products-select-target' => 'productSelect'
          }
        },
        wrapper_html: {
          data: {
            controller: 'form-hint-url',
          }
        },
        collection: basket_content_products_collection,
        required: true,
        prompt: true,
        hint: link_to(f.object.product&.url_domain.to_s, f.object.product&.url, target: '_blank', data: { 'form-hint-url-target' => 'link' })
      f.input :unit,
        collection: units_collection,
        prompt: true,
        input_html: {
          data: {
            action: 'basket-content-products-select#unitChange',
            'basket-content-products-select-target' => 'unitSelect'
          }
        }
      f.input :quantity,
        input_html: {
          data: {
            'basket-content-products-select-target' => 'quantityInput'
          }
        }
      f.input :unit_price,
        label: BasketContent.human_attribute_name(:price),
        as: :number,
        min: 0,
        step: 0.05,
        input_html: {
          data: {
            'basket-content-products-select-target' => 'unitPriceInput'
          }
        }
    end
    div 'data-controller' => 'basket-content-distribution' do
      h2 t('basket_content.distribution')
      tabs  do
        tab t('basket_content.distribution_mode.automatic'), id: 'automatic', html_options: { class: ('ui-tabs-active' if f.object.distribution_automatic?), 'data-action' => 'click->basket-content-distribution#automaticMode' } do
          f.inputs do
            f.semantic_errors :basket_percentages
            BasketSize.paid.each do |basket_size|
              f.input :basket_size_ids_percentages,
                as: :custom_range,
                step: 1,
                min: 0,
                max: 100,
                label: basket_size.name,
                required: true,
                wrapper_html: {
                  id: nil,
                  class: 'basket_content_distribution_wrapper'
                },
                hint: '%',
                input_html: {
                  id: "basket_size_ids_percentages_#{basket_size.id}",
                  value: f.object.basket_percentage(basket_size),
                  name: "basket_content[basket_size_ids_percentages][#{basket_size.id}]",
                  data: {
                    'basket-content-distribution-target' => 'input',
                    'action' => 'blur->basket-content-distribution#change'
                  }
                },
                range_html: {
                  id: "basket_size_ids_percentages_#{basket_size.id}_range",
                  name: "basket_content[basket_size_ids_percentages_range][#{basket_size.id}]",
                  data: {
                    'basket-content-distribution-target' => 'range',
                    'action' => 'basket-content-distribution#change'
                  }
                }
            end
            span class: 'basket_size_ids_percentages_sum',
              style: 'display: none;',
              'data-basket-content-distribution-target' => 'sum'
            div class: 'basket_size_ids_percentages_presets' do
              a class: 'button',
                  'data-basket-content-distribution-target' => 'preset',
                  'data-action' => 'basket-content-distribution#applyPreset',
                  'data-preset' => f.object.basket_size_ids_percentages_pro_rated.to_json do
                t('basket_content.preset.basket_content_percentages_pro_rated')
              end
              a class: 'button',
                  'data-basket-content-distribution-target' => 'preset',
                  'data-action' => 'basket-content-distribution#applyPreset',
                  'data-preset' => f.object.basket_size_ids_percentages_even.to_json do
                t('basket_content.preset.basket_content_percentages_even')
              end
            end
            para class: 'basket_content_distribution_wrapper_hint inline-hints' do
              t('basket_content.percentages_hint')
            end
          end
        end
        tab t('basket_content.distribution_mode.manual'), id: 'manual', html_options: { class: ('ui-tabs-active' if f.object.distribution_manual?), 'data-action' => 'click->basket-content-distribution#manualMode' } do
          f.inputs do
            f.semantic_errors :basket_quantities
            BasketSize.paid.each do |basket_size|
              f.input :basket_size_ids_quantities,
                as: :number,
                step: 1,
                min: 0,
                label: basket_size.name,
                hint: 'En g ou à la pièce',
                wrapper_html: { id: nil },
                input_html: {
                  id: "basket_size_ids_quantities_#{basket_size.id}",
                  value: f.object.basket_size_ids_quantity(basket_size),
                  name: "basket_content[basket_size_ids_quantities][#{basket_size.id}]",
                  data: {
                    'basket-content-distribution-target' => 'quantityInput'
                  }
                }
            end
          end
        end
      end
    end
    f.inputs do
      f.input :depots,
        collection: Depot.all,
        as: :check_boxes
    end
    f.actions
  end

  permit_params(*%i[delivery_id product_id quantity unit unit_price],
    depot_ids: [],
    basket_size_ids_percentages: {},
    basket_size_ids_quantities: {})

  before_action only: :index do
    if params.except(:subdomain, :controller, :action).empty? &&
        params[:q].blank? &&
        (delivery = Delivery.next || Delivery.last)
      redirect_to q: { delivery_id_eq: delivery.id }, utf8: '✓'
    end
  end

  before_build do |basket_content|
    basket_content.delivery_id ||= referer_filter(:delivery_id) || Delivery.next&.id
    if basket_content.depots.empty?
      basket_content.depots = Depot.all
    end
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper

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
        .joins(:delivery, :product)
        .merge(Delivery.reorder(date: :desc))
        .merge(BasketContent::Product.order_by_name)
    end
  end
end
