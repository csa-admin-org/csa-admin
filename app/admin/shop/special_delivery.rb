ActiveAdmin.register Shop::SpecialDelivery do
  menu parent: :shop, priority: 4
  actions :all

  breadcrumb do
    if params['action'] == 'index'
      [t('active_admin.menu.shop')]
    else
      links = [
        t('active_admin.menu.shop'),
        link_to(Shop::SpecialDelivery.model_name.human(count: 2), shop_special_deliveries_path)
      ]
      if params['action'].in? %W[edit]
        links << I18n.l(shop_special_delivery.date)
      end
      links
    end
  end

  scope :all
  scope :coming, default: true
  scope :past

  filter :open
  filter :date
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  # Workaround for ActionController::UnknownFormat (xlsx download)
  # https://github.com/activeadmin/activeadmin/issues/4945#issuecomment-302729459
  includes :shop_orders
  index download_links: -> { params[:action] == 'show' ? [:xlsx] : false } do
    column :date, ->(d) { auto_link d, l(d.date, format: :medium_long).capitalize }
    column :open_until, ->(d) {
      if d.shop_open?
        l(d.shop_closing_at, format: :medium_long).capitalize
      else
        status_tag :closed, class: 'red'
      end
    }
    column Shop::Product.model_name.human(count: 2), ->(d) {
      link_to(
        d.shop_products_count,
        edit_shop_special_delivery_path(d, anchor: 'products'))
    }, sortable: :shop_products_count
    column :orders, ->(d) {
      link_to(
        d.shop_orders_count,
        shop_orders_path(
          q: { _delivery_gid_eq: d.gid }, scope: :all_without_cart))
    }, sortable: :shop_orders_count
    actions defaults: true, class: 'col-actions-5' do |delivery|
      link_to('XLSX', shop_special_delivery_path(delivery, format: :xlsx), class: 'xlsx_link') +
        link_to('PDF', delivery_shop_orders_path(delivery_gid: delivery.gid, format: :pdf), class: 'pdf_link', target: '_blank')
    end
  end

  sidebar_shop_admin_only_warning

  sidebar_handbook_link('shop#livraisons-spciales')

  show title: ->(d) { d.display_name(format: :long).capitalize } do |delivery|
    columns do
      column do
        all = Shop::DeliveryTotal.all_by_producer(delivery)
        if all.empty?
          panel '' do
            em t('.no_orders')
          end
        else
          all.each do |producer, items|
            xlsx_link = "<span class='link'>#{link_to('XLSX', shop_special_delivery_path(delivery, format: :xlsx, producer_id: producer.id), class: 'xlsx_link')}</span>"
            panel (producer.name + xlsx_link).html_safe do
              table_for items, class: 'totals', i18n: Shop::OrderItem do
                column(:product) { |i| auto_link i.product }
                column(:product_variant) { |i| i.product_variant }
                column(:quantity)
                column(:amount) { |i| cur(i.amount) }
              end
            end
          end
        end
      end
      column do
        attributes_table do
          row(:date) { l(delivery.date, format: :medium_long) }
          row(:open) { status_tag(delivery.shop_open?) }
          if delivery.shop_open?
            row(:open_until) { l(delivery.shop_closing_at, format: :medium_long) }
          end
          row(:products) {
            link_to(
              delivery.shop_products_count,
              edit_shop_special_delivery_path(delivery, anchor: 'products'))
          }
          row(:orders) {
            link_to(
              delivery.shop_orders_count,
              shop_orders_path(
                q: { _delivery_gid_eq: delivery.gid }, scope: :all_without_cart))
                }
        end
        panel Shop::SpecialDelivery.human_attribute_name(:description) do
          if delivery.shop_text?
            delivery.shop_text
          else
            para(class: 'empty') { t('active_admin.empty') }
          end
        end
        active_admin_comments
      end
    end
  end

  action_item :xlsx, only: :show do
    link_to('XLSX', [resource, format: :xlsx], class: 'xlsx_link')
  end

  action_item :pdf, only: :show do
    link_to t('.delivery_orders_pdf'), delivery_shop_orders_path(delivery_gid: resource.gid, format: :pdf), target: '_blank'
  end

  form do |f|
    f.inputs t('.details') do
      f.input :open
      f.input :date, as: :date_picker
      f.input :open_delay_in_days, hint: t('formtastic.hints.acp.shop_delivery_open_delay_in_days')
      f.input :open_last_day_end_time,
        as: :time_picker,
        hint: t('formtastic.hints.acp.shop_delivery_open_last_day_end_time'),
        input_html: {
          value: f.object.open_last_day_end_time&.strftime('%H:%M')
        }
      translated_input(f, :shop_texts,
        as: :action_text,
        required: false,
        hint: t('formtastic.hints.acp.shop_text'))
    end

    f.inputs Shop::SpecialDelivery.human_attribute_name(:products), id: 'products' do
      Shop::Product
        .includes(:producer)
        .group_by(&:producer)
        .sort_by { |p, pp| p.name }
        .each do |producer, products|
          f.input :products,
            label: producer.name,
            as: :check_boxes,
            collection: products.map { |p|
              [p.display_name, p.id]
            },
            hint: t('formtastic.hints.shop/special_delivery.products')
        end
    end
    f.actions
  end

  permit_params \
    :date,
    :open_delay_in_days, :open_last_day_end_time,
    :open,
    *I18n.available_locales.map { |l| "shop_text_#{l}" },
    product_ids: []

  controller do
    include TranslatedCSVFilename

    def apply_sorting(chain)
      params[:order] ||= 'date_desc' if params[:scope] == 'past'
      super
    end

    def show
      respond_to do |format|
        format.html
        format.xlsx do
          producer = Shop::Producer.find(params[:producer_id]) if params[:producer_id]
          xlsx = XLSX::Shop::Delivery.new(resource, producer)
          send_data xlsx.data,
            content_type: xlsx.content_type,
            filename: xlsx.filename
        end
      end
    end
  end

  config.sort_order = 'date_asc'
end
