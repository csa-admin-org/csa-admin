ActiveAdmin.register Delivery do
  menu parent: :other, priority: 10

  scope :past_year
  scope :current_year, default: true
  scope :future_year

  filter :date
  filter :note, as: :string

  # Workaround for ActionController::UnknownFormat (xlsx download)
  # https://github.com/activeadmin/activeadmin/issues/4945#issuecomment-302729459
  index download_links: -> { params[:action] == 'show' ? [:xlsx, :pdf] : [:csv] } do
    column '#', ->(delivery) { auto_link delivery, delivery.number }
    column :date, ->(delivery) { auto_link delivery, l(delivery.date) }
    column :note, ->(delivery) { truncate delivery.note, length: 175 }
    actions defaults: true do |delivery|
      link_to('XLSX', delivery_path(delivery, format: :xlsx), class: 'xlsx_link') +
        link_to('PDF', delivery_path(delivery, format: :pdf), class: 'pdf_link')
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
  end

  show do |delivery|
    columns do
      column do
        panel Basket.model_name.human(count: 2) do
          counts = delivery.basket_counts
          if counts.present?
            table_for counts.all do
              column Depot.model_name.human, :title
              column Basket.model_name.human, :count, class: 'align-right'
              column "#{BasketSize.all.map(&:name).join(' /&nbsp;')}".html_safe, :baskets_count, class: 'align-right'
            end

            if Depot.paid.any?
              free_depots = Depot.free
              paid_depots = Depot.paid
              free_counts = BasketCounts.new(delivery, free_depots.pluck(:id))
              paid_counts = BasketCounts.new(delivery, paid_depots.pluck(:id))
              totals = [
                OpenStruct.new(
                  title: "#{Basket.model_name.human(count: 2)}: #{free_depots.pluck(:name).to_sentence}",
                  count: t('.total', number: free_counts.sum),
                  baskets_count: t('.totals', numbers: free_counts.sum_detail)),
                OpenStruct.new(
                  title: t('.baskets_to_prepare'),
                  count: t('.total', number: paid_counts.sum),
                  baskets_count: t('.totals', numbers: paid_counts.sum_detail))
              ]
              table_for totals do
                column nil, :title
                column nil, :count, class: 'align-right'
                column nil, :baskets_count, class: 'align-right'
              end
            end

            table_for nil do
              column nil, :title
              column(class: 'align-right') { "Total: #{counts.sum}" }
              column(class: 'align-right') { t('.totals', numbers: counts.sum_detail) }
            end

            if BasketComplement.any?
              counts = BasketComplementCount.all(delivery)
              div id: 'basket-complements-table' do
                if counts.any?
                  table_for counts do
                    column BasketComplement.model_name.human, :title
                    column t('.total', number: ''), :count, class: 'align-right'
                  end
                else
                  em t('.no_basket_complements')
                end
              end
            end

            span do
              link_to Delivery.human_attribute_name(:xlsx_recap), delivery_path(delivery, format: :xlsx)
            end
            span { '&nbsp;/&nbsp;'.html_safe }
            span do
              link_to Delivery.human_attribute_name(:signature_sheets), delivery_path(delivery, format: :pdf)
            end
          end
        end
      end

      column do
        attributes_table do
          row('#') { delivery.number }
          row(:date) { l delivery.date }
        end

        panel link_to(Absence.model_name.human(count: 2), absences_path(q: { including_date: delivery.date }, scope: :all)) do
          absences = Absence.including_date(delivery.date).includes(:member)
          if absences.any?
            absences.map { |a| auto_link a.member }.join(', ').html_safe
          else
            content_tag :span, t('active_admin.empty'), class: 'empty'
          end
        end

        attributes_table title: t('.notes') do
          row(:note) { text_format(delivery.note) }
        end

        active_admin_comments
      end
    end
  end

  form do |f|
    render partial: 'bulk_dates', locals: { f: f, resource: resource }
    f.inputs do
      f.input :note
      if !f.object.new_record? && BasketComplement.any?
        f.input :basket_complements,
          as: :check_boxes,
          collection: BasketComplement.all,
          hint: true
      end
      f.actions
    end
  end

  controller do
    def show
      respond_to do |format|
        format.html
        format.xlsx do
          xlsx = XLSX::Delivery.new(resource)
          send_data xlsx.data,
            content_type: xlsx.content_type,
            filename: xlsx.filename
        end
        format.pdf do
          pdf = PDF::Delivery.new(resource)
          send_data pdf.render,
            content_type: pdf.content_type,
            filename: pdf.filename
        end
      end
    end

    def update
      super do |success, _failure|
        success.html { redirect_to root_path }
      end
    end
  end

  permit_params \
    :note,
    :date,
    :bulk_dates_starts_on, :bulk_dates_ends_on,
    :bulk_dates_weeks_frequency,
    bulk_dates_wdays: [],
    basket_complement_ids: []

  config.sort_order = 'date_asc'
  config.per_page = 52
end
