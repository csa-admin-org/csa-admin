ActiveAdmin.register Delivery do
  menu parent: :other, priority: 10

  scope :all
  scope :coming, default: true
  scope :past

  filter :basket_complements,
    as: :select,
    collection: -> { BasketComplement.all },
    if: :any_basket_complements?
  filter :note, as: :string
  filter :shop_open,
    as: :boolean,
    if: -> proc { Current.acp.feature?('shop') }
  filter :date
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  includes :basket_complements, :basket_complements_deliveries

  # Workaround for ActionController::UnknownFormat (xlsx download)
  # https://github.com/activeadmin/activeadmin/issues/4945#issuecomment-302729459
  index download_links: -> { params[:action] == 'show' ? [:xlsx, :pdf] : [:csv] } do
    if Current.acp.feature?('shop') && (!params[:scope] || params[:scope] == 'coming')
      selectable_column
    end
    column '#', ->(delivery) { auto_link delivery, delivery.number }
    column :date, ->(delivery) { auto_link delivery, l(delivery.date, format: :medium_long).capitalize }
    if BasketComplement.any?
      column(:basket_complements) { |d| d.basket_complements.map(&:name).to_sentence }
    end
    if Current.acp.feature?('shop')
      column :shop, ->(delivery) { status_tag(delivery.shop_open?) }
    end
    actions defaults: true, class: 'col-actions-5' do |delivery|
      link_to('XLSX', delivery_path(delivery, format: :xlsx), class: 'xlsx_link') +
        link_to('PDF', delivery_path(delivery, format: :pdf), class: 'pdf_link', target: '_blank')
    end
  end

  csv do
    column(:id)
    column(:date)
    column(:baskets) { |d| d.basket_counts.all.sum(&:count) }
    column(:absent_baskets) { |d| d.basket_counts(scope: :absent).all.sum(&:count) }

    Depot.all.each do |depot|
      column(depot.name) { |d| BasketCounts.new(d, depot.id).sum }
    end

    BasketSize.all.each do |basket_size|
      column(basket_size.name) { |d| d.basket_counts.sum_basket_size(basket_size.id) }
    end

    if BasketComplement.any?
      BasketComplement.all.each do |basket_complement|
        column(basket_complement.name) { |d| BasketComplementCount.new(basket_complement, d).count }
      end
    end

    DeliveriesCycle.all.each do |deliveries_cycle|
      column(deliveries_cycle.name) { |d| deliveries_cycle.include_delivery?(d) }
    end

    if Current.acp.feature?('shop')
      column(:shop_open)
    end
  end

  action_item :deliveries_cycle, only: :index do
    link_to DeliveriesCycle.model_name.human(count: 2), deliveries_cycles_path
  end

  sidebar_handbook_link('deliveries')

  show title: ->(d) { d.display_name(format: :long).capitalize } do |delivery|
    columns do
      column do
        panel Basket.model_name.human(count: 2) do
          div class: 'actions' do
            icon_link(:xlsx_file, Delivery.human_attribute_name(:summary), delivery_path(delivery, format: :xlsx)) +
            icon_link(:pdf_file, Delivery.human_attribute_name(:sheets), delivery_path(delivery, format: :pdf), target: '_blank')
          end

          counts = delivery.basket_counts
          if counts.present?
            render partial: 'active_admin/deliveries/baskets',
              locals: { delivery: delivery, scope: :not_absent }
          end
        end

        if Current.acp.feature?('absence')
          absences = Absence.including_date(delivery.date).includes(:member)
          panel link_to("#{Absence.model_name.human(count: 2)} (#{absences.count})", absences_path(q: { including_date: delivery.date }, scope: :all)) do
            absent_counts = delivery.basket_counts(scope: :absent)
            if absent_counts.present?
              render partial: 'active_admin/deliveries/baskets',
                locals: { delivery: delivery, scope: :absent }
            else
              content_tag :span, t('active_admin.empty'), class: 'empty'
            end
          end
        end
      end

      column do
        attributes_table do
          row('#') { delivery.number }
          row(:date) { l(delivery.date, format: :long) }
          row(:note) { text_format(delivery.note) }
        end

        if Current.acp.feature?('shop')
          attributes_table title: t('shop.title') do
            row(t('shop.open')) { status_tag(delivery.shop_open?) }
            if delivery.shop_open
              row(:depots) { display_depots(delivery.shop_open_for_depots) }
            end
            row(Shop::Order.model_name.human(count: 2)) {
              orders_count = delivery.shop_orders.all_without_cart.count
              if orders_count.positive?
                link_to(orders_count, shop_orders_path(q: { _delivery_gid_eq: delivery.gid }, scope: :all_without_cart))
              else
                content_tag :span, t('active_admin.empty'), class: 'empty'
              end
            }
          end
        end

        if Current.acp.feature?('basket_content')
          basket_contents = delivery.basket_contents.includes(:product)
          panel link_to(BasketContent.model_name.human(count: 2), basket_contents_path(q: { delivery_id_eq: delivery.id })) do
            if basket_contents.any?
              basket_contents.map { |bc| bc.product.name }.sort.to_sentence.html_safe
            else
              content_tag :span, t('active_admin.empty'), class: 'empty'
            end
          end
        end

        active_admin_comments
      end
    end
  end

  form do |f|
    render partial: 'bulk_dates', locals: { f: f, resource: resource, context: self }
    if f.object.new_record? && BasketComplement.any?
      f.inputs do
        f.input :basket_complements,
          as: :check_boxes,
          collection: BasketComplement.all,
          hint: true

        para class: 'actions' do
          a href: handbook_page_path('deliveries', anchor: 'complments-de-panier'), class: 'action' do
            span do
              span inline_svg_tag('admin/book-open.svg', size: '20', title: t('layouts.footer.handbook'))
              span t('.check_handbook')
            end
          end.html_safe
        end
      end
    end
    f.inputs do
      f.input :note, as: :text, input_html: { rows: 3 }
    end
    if Current.acp.feature?('shop')
      f.inputs t('shop.title'), 'data-controller' => 'form-checkbox-toggler' do
        f.input :shop_open,
          as: :boolean,
          input_html: { data: {
            form_checkbox_toggler_target: 'checkbox',
            action: 'form-checkbox-toggler#toggleInput'
          } }
        f.input :shop_open_for_depot_ids,
          label: Depot.model_name.human(count: 2),
          as: :check_boxes,
          required: false,
          collection: Depot.all.map,
          input_html: {
            data: { form_checkbox_toggler_target: 'input' }
          }
      end
    end
    f.actions
  end

  permit_params \
    :note,
    :date,
    :bulk_dates_starts_on, :bulk_dates_ends_on,
    :bulk_dates_weeks_frequency,
    :shop_open,
    bulk_dates_wdays: [],
    shop_open_for_depot_ids: [],
    basket_complement_ids: []

  batch_action :destroy, false

  batch_action :open_shop, if: ->(attr) { Current.acp.feature?('shop') && (!params[:scope] || params[:scope] == 'coming') } do |selection|
    Delivery.where(id: selection).update_all(shop_open: true)
    redirect_back fallback_location: collection_path
  end

  batch_action :close_shop, if: ->(attr) { Current.acp.feature?('shop') && (!params[:scope] || params[:scope] == 'coming') } do |selection|
    Delivery.where(id: selection).update_all(shop_open: false)
    redirect_back fallback_location: collection_path
  end

  controller do
    include TranslatedCSVFilename

    def show
      depot = Depot.find(params[:depot_id]) if params[:depot_id]
      super do |success, _failure|
        success.html
        success.xlsx do
          xlsx =
            if params[:shop]
              XLSX::Shop::Delivery.new(resource, nil, depot: depot)
            else
              XLSX::Delivery.new(resource, depot)
            end
          send_data xlsx.data,
            content_type: xlsx.content_type,
            filename: xlsx.filename
        end
        success.pdf do
          pdf = PDF::Delivery.new(resource, depot)
          send_data pdf.render,
            content_type: pdf.content_type,
            filename: pdf.filename,
            disposition: 'inline'
        end
      end
    end
  end

  config.batch_actions = true
  config.sort_order = 'date_asc'
  config.per_page = 52
end
