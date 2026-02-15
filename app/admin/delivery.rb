# frozen_string_literal: true

ActiveAdmin.register Delivery do
  menu parent: :other, priority: 10

  scope :all
  scope :coming, group: :period, default: true
  scope :past, group: :period

  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :date
  filter :wday, as: :select, collection: -> { wdays_collection }
  filter :month, as: :select, collection: -> { months_collection }
  filter :basket_complements,
    as: :select,
    collection: -> { admin_basket_complements_collection },
    if: :any_basket_complements?
  filter :shop_open,
    label: -> { t("shop.title") },
    as: :boolean,
    if: ->(proc) { feature?("shop") }
  filter :note, as: :string

  includes :basket_complements, :basket_complements_deliveries

  # Workaround for ActionController::UnknownFormat (xlsx download)
  # https://github.com/activeadmin/activeadmin/issues/4945#issuecomment-302729459
  index download_links: -> { params[:action] == "show" ? [ :xlsx, :pdf ] : [ :csv ] }, class: "table-auto" do
    if feature?("shop") && (!params[:scope] || params[:scope] == "coming")
      selectable_column(class: "w-px")
    end
    column "#", ->(delivery) { delivery.number }, class: "w-px"
    column :date, ->(delivery) { l(delivery.date, format: :medium).capitalize }, class: "text-right whitespace-nowrap"
    if BasketComplement.kept.any?
      column(:basket_complements) { |d| d.basket_complements.map(&:name).to_sentence }
    end
    if feature?("shop")
      column :shop, ->(delivery) { status_tag(delivery.shop_configured_open?) }, class: "text-right w-px"
    end
    actions class: "w-px" do |delivery|
      icon_file_link(:csv, baskets_path(q: { delivery_id_eq: delivery.id }, format: :csv), title: Delivery.human_attribute_name(:summary), size: 5) +
      icon_file_link(:xlsx, delivery_path(delivery, format: :xlsx), title: Delivery.human_attribute_name(:summary), size: 5) +
      icon_file_link(:pdf, delivery_path(delivery, format: :pdf), target: "_blank", title: Delivery.human_attribute_name(:sheets), size: 5)
    end
  end

  csv do
    column(:id)
    column(:fiscal_year)
    column(:date)
    column(:number)
    column(:baskets) { |d| d.basket_counts.all.sum(&:count) }
    column(:absent_baskets) { |d| d.basket_counts(scope: :absent).all.sum(&:count) }
    if BasketComplement.kept.any?
      column(:basket_complements) { |d| d.basket_complements.map(&:name).to_sentence }
    end
    if feature?("shop")
      column("#{t("shop.title")}: #{Delivery.human_attribute_name(:shop_open)}") { |d| d.shop_configured_open? }
    end
    column(:basket_size_price_percentage)
    column(:note)
  end

  action_item :delivery_cycle, only: :index do
    action_link DeliveryCycle.model_name.human(count: 2), delivery_cycles_path
  end

  action_item :baskets_csv, only: :index, if: -> { params.dig(:q, :during_year).present? } do
    action_link Basket.model_name.human(count: 2), baskets_path(q: { during_year: params.dig(:q, :during_year) }, format: :csv),
      target: "_blank",
      icon: "file-csv"
  end

  sidebar_handbook_link("deliveries")

  show title: ->(d) { d.display_name(format: :long, capitalize: true) } do |delivery|
    columns do
      column do
        panel Basket.model_name.human(count: 2), action: (
          icon_file_link(:csv, baskets_path(q: { delivery_id_eq: delivery.id }, format: :csv), title: Delivery.human_attribute_name(:summary)) +
          icon_file_link(:xlsx, delivery_path(delivery, format: :xlsx), title: Delivery.human_attribute_name(:summary)) +
          icon_file_link(:pdf, delivery_path(delivery, format: :pdf), target: "_blank", title: Delivery.human_attribute_name(:sheets))
        ) do
          counts = delivery.basket_counts
          if counts.present?
            render partial: "active_admin/deliveries/baskets",
              locals: { delivery: delivery, scope: :active }
          end
        end

        if feature?("absence")
          panel link_to(Absence.model_name.human(count: 2), absences_path(q: { including_date: delivery.date }, scope: :all)) do
            absent_counts = delivery.basket_counts(scope: :absent)
            if absent_counts.present?
              render partial: "active_admin/deliveries/baskets",
                locals: { delivery: delivery, scope: :absent }
            else
              div(class: "missing-data") { t("active_admin.empty") }
            end
          end
        end
      end

      column do
        panel t(".details") do
          attributes_table do
            row("#") { delivery.number }
            row(:cweek) { delivery.date.cweek }
            row(:note) { text_format(delivery.note) }
          end
        end

        panel Delivery.human_attribute_name(:sheets_pdf) do
          attributes_table do
            row(Announcement.model_name.human(count: 2)) {
              count = Announcement.active.deliveries_eq(delivery.id).count
              link_to t("announcements.active", count: count), announcements_path(scope: :active, q: { deliveries_eq: delivery.id })
            }
          end
        end

        if delivery.basket_size_price_percentage?
          panel t(".billing") do
            attributes_table do
              row(:basket_size_price) { number_to_percentage(delivery.basket_size_price_percentage || 100, precision: 0) }
            end
          end
        end

        if feature?("shop")
          panel t("shop.title") do
          attributes_table do
              row(t("shop.open")) { status_tag(delivery.shop_open?) }
              if delivery.shop_open
                row(:depots) { display_depots(delivery.shop_open_for_depots) }
              end
              row(Shop::Order.model_name.human(count: 2)) {
                orders_count = delivery.shop_orders.all_without_cart.count
                if orders_count.positive?
                  link_to(orders_count, shop_orders_path(q: { _delivery_gid_eq: delivery.gid }, scope: :all_without_cart))
                else
                  content_tag :span, t("active_admin.empty"), class: "italic text-gray-400 dark:text-gray-600"
                end
              }
            end
          end
        end

        if feature?("basket_content")
          basket_contents = delivery.basket_contents.includes(:product)
          panel link_to(BasketContent.model_name.human(count: 2), basket_contents_path(q: { delivery_id_eq: delivery.id })) do
            if basket_contents.any?
              div class: "p-2" do
                basket_contents.map { |bc| bc.product.name }.sort.to_sentence.html_safe
              end
            else
              div(class: "missing-data") { t("active_admin.empty") }
            end
          end
        end

        active_admin_comments_for(delivery)
      end
    end
  end

  form do |f|
    if f.object.new_record? && Delivery.current_year_ongoing?
      warning_pane do
        t("active_admin.resources.delivery.ongoing_fiscal_year_warning_html", year: Current.fiscal_year).html_safe
      end
    end

    render partial: "bulk_dates", locals: { f: f, resource: resource, context: self }

    if f.object.new_record? && BasketComplement.kept.any?
      f.inputs do
        f.input :basket_complements,
          as: :check_boxes,
          wrapper_html: { class: "legend-title" },
          collection: admin_basket_complements,
          hint: true

        handbook_button(self, "deliveries", anchor: "complments-de-panier")
      end
    end

    f.inputs t(".billing") do
      f.input :basket_size_price_percentage,
        as: :number,
        step: 1,
        input_html: { min: 0 }
    end

    if feature?("shop")
      f.inputs t("shop.title"), "data-controller" => "form-checkbox-toggler" do
        f.input :shop_open,
          as: :boolean,
          input_html: { data: {
            form_checkbox_toggler_target: "checkbox",
            action: "form-checkbox-toggler#toggleInput"
          } }
        f.input :shop_open_for_depot_ids,
          label: Depot.model_name.human(count: 2),
          as: :check_boxes,
          for: Depot,
          required: false,
          collection: admin_depots,
          input_html: {
            data: { form_checkbox_toggler_target: "input" }
          }
      end
    end

    f.inputs t(".details") do
      f.input :note, as: :text, input_html: { rows: 3 }
    end

    f.actions
  end

  permit_params \
    :note,
    :date,
    :bulk_dates_starts_on, :bulk_dates_ends_on,
    :bulk_dates_weeks_frequency,
    :shop_open,
    :basket_size_price_percentage,
    bulk_dates_wdays: [],
    shop_open_for_depot_ids: [],
    basket_complement_ids: []

  batch_action :destroy, false

  batch_action :open_shop, if: proc { feature?("shop") && (!params[:scope] || params[:scope] == "coming") } do |selection|
    Delivery.where(id: selection).update_all(shop_open: true)
    redirect_back fallback_location: collection_path
  end

  batch_action :close_shop, if: proc { feature?("shop") && (!params[:scope] || params[:scope] == "coming") } do |selection|
    Delivery.where(id: selection).update_all(shop_open: false)
    redirect_back fallback_location: collection_path
  end

  before_action only: :index do
    if params.dig(:q, :during_year).present? && params.dig(:q, :during_year).to_i < Current.fy_year
      params[:scope] ||= "all"
    end
  end

  controller do
    include TranslatedCSVFilename

    def apply_sorting(chain)
      if params[:scope] == "past" && !params[:order]
        params[:order] = "date_desc"
      end
      super(chain)
    end

    def show
      depot = Depot.find(params[:depot_id]) if params[:depot_id].present?
      super do |success, _failure|
        success.html
        success.xlsx do
          xlsx =
            if params[:shop]
              XLSX::Shop::OrderItem.new(resource.shop_orders.all_without_cart, nil, depot: depot)
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
            disposition: "inline"
        end
      end
    end
  end

  config.batch_actions = true
  config.sort_order = "date_asc"
  config.per_page = 52
end
