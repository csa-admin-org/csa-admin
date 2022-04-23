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
    column(:absent_baskets) { |d| d.basket_counts.all.sum(&:absent_count) }

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
          counts = delivery.basket_counts
          if counts.present?
            render partial: 'active_admin/deliveries/baskets', locals: { delivery: delivery }
          end
        end
      end

      column do
        attributes_table do
          row('#') { delivery.number }
          row(:date) { l(delivery.date, format: :long) }
        end

        if Current.acp.feature?('shop')
          attributes_table title: t('shop.title') do
            row(t('shop.open')) { status_tag(delivery.shop_open?)}
            row(Shop::Order.model_name.human(count: 2)) {
              orders_count = delivery.shop_orders.all_without_cart.count
              if orders_count.positive?
                link_to(orders_count, shop_orders_path(q: { delivery_id_eq: delivery.id }, scope: :all_without_cart))
              else
                content_tag :span, t('active_admin.empty'), class: 'empty'
              end
            }
          end
        end

        if Current.acp.feature?('basket_content')
          basket_contents = delivery.basket_contents.includes(:vegetable)
          panel link_to(BasketContent.model_name.human(count: 2), basket_contents_path(q: { delivery_id_eq: delivery.id })) do
            if basket_contents.any?
              basket_contents.map { |bc| bc.vegetable.name }.sort.to_sentence.html_safe
            else
              content_tag :span, t('active_admin.empty'), class: 'empty'
            end
          end
        end

        if Current.acp.feature?('absence')
          absences = Absence.including_date(delivery.date).includes(:member)
          panel link_to("#{Absence.model_name.human(count: 2)} (#{absences.count})", absences_path(q: { including_date: delivery.date }, scope: :all)) do
            if absences.any?
              absences.map { |a| auto_link a.member }.to_sentence.html_safe
            else
              content_tag :span, t('active_admin.empty'), class: 'empty'
            end
          end
        end

        attributes_table title: t('.notes') do
          row(:note) { text_format(delivery.note) }
        end

        active_admin_comments
      end
    end
  end

  action_item :xlsx_summary, only: :show do
    link_to Delivery.human_attribute_name(:summary_xlsx), delivery_path(delivery, format: :xlsx)
  end

  action_item :signature_sheets, only: :show do
    link_to Delivery.human_attribute_name(:signature_sheets_pdf), delivery_path(delivery, format: :pdf), target: '_blank'
  end

  form do |f|
    render partial: 'bulk_dates', locals: { f: f, resource: resource, context: self }
    if BasketComplement.any?
      f.inputs do
        f.input :basket_complements,
          as: :check_boxes,
          collection: BasketComplement.all,
          hint: true

        para class: 'actions' do
          a href: handbook_page_path('deliveries', anchor: 'complments-de-panier'), class: 'action' do
            span do
              span inline_svg_tag('admin/book-open.svg', size: '20', title: I18n.t('layouts.footer.handbook'))
              span t('.check_handbook')
            end
          end.html_safe
        end
      end
    end
    f.inputs do
      if Current.acp.feature?('shop')
        f.input :shop_open, as: :boolean
      end
      f.input :note
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
    basket_complement_ids: []

  controller do
    include TranslatedCSVFilename

    def show
      super do |success, _failure|
        success.html
        success.xlsx do
          xlsx = XLSX::Delivery.new(resource)
          send_data xlsx.data,
            content_type: xlsx.content_type,
            filename: xlsx.filename
        end
        success.pdf do
          pdf = PDF::Delivery.new(resource)
          send_data pdf.render,
            content_type: pdf.content_type,
            filename: pdf.filename,
            disposition: 'inline'
        end
      end
    end
  end

  config.sort_order = 'date_asc'
  config.per_page = 52
end
