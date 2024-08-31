# frozen_string_literal: true

ActiveAdmin.register Delivery do
  menu parent: :other, priority: 10

  scope :all
  scope :coming, default: true
  scope :past

  filter :basket_complements,
    as: :select,
    collection: -> { admin_basket_complements_collection },
    if: :any_basket_complements?
  filter :note, as: :string
  filter :shop_open,
    as: :boolean,
    if: ->(proc) { Current.org.feature?("shop") }
  filter :date
  filter :wday, as: :select, collection: -> { wdays_collection }
  filter :month, as: :select, collection: -> { months_collection }
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  includes :basket_complements, :basket_complements_deliveries

  # Workaround for ActionController::UnknownFormat (xlsx download)
  # https://github.com/activeadmin/activeadmin/issues/4945#issuecomment-302729459
  index download_links: -> { params[:action] == "show" ? [ :xlsx, :pdf ] : [ :csv ] } do
    if Current.org.feature?("shop") && (!params[:scope] || params[:scope] == "coming")
      selectable_column
    end
    column "#", ->(delivery) { auto_link delivery, delivery.number }
    column :date, ->(delivery) { auto_link delivery, l(delivery.date, format: :medium).capitalize }, class: "text-right"
    if BasketComplement.kept.any?
      column(:basket_complements) { |d| d.basket_complements.map(&:name).to_sentence }
    end
    if Current.org.feature?("shop")
      column :shop, ->(delivery) { status_tag(delivery.shop_configured_open?) }, class: "text-right"
    end
    actions do |delivery|
      div do
        link_to baskets_path(q: { delivery_id_eq: delivery.id }, format: :csv), title: "CSV" do
          inline_svg_tag "admin/csv_file.svg", class: "w-5 h-5"
        end
      end
      div do
        link_to delivery_path(delivery, format: :xlsx), title: "XLSX" do
          inline_svg_tag "admin/xlsx_file.svg", class: "w-5 h-5"
        end
      end
      div do
        link_to delivery_path(delivery, format: :pdf), target: "_blank", title: "PDF" do
          inline_svg_tag "admin/pdf_file.svg", class: "w-5 h-5"
        end
      end
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
    if Current.org.feature?("shop")
      column("#{t("shop.title")}: #{Delivery.human_attribute_name(:shop_open)}") { |d| d.shop_configured_open? }
    end
    column(:note)
  end

  action_item :delivery_cycle, only: :index do
    link_to DeliveryCycle.model_name.human(count: 2), delivery_cycles_path, class: "action-item-button"
  end

  sidebar_handbook_link("deliveries")

  show title: ->(d) { d.display_name(format: :long).capitalize } do |delivery|
    columns do
      column do
        panel Basket.model_name.human(count: 2), action: (
          icon_link(:csv_file, Delivery.human_attribute_name(:summary), baskets_path(q: { delivery_id_eq: delivery.id }, format: :csv)) +
          icon_link(:xlsx_file, Delivery.human_attribute_name(:summary), delivery_path(delivery, format: :xlsx)) +
          icon_link(:pdf_file, Delivery.human_attribute_name(:sheets), delivery_path(delivery, format: :pdf), target: "_blank")
        ) do
          counts = delivery.basket_counts
          if counts.present?
            render partial: "active_admin/deliveries/baskets",
              locals: { delivery: delivery, scope: :active }
          end
        end

        if Current.org.feature?("absence")
          absences = Absence.including_date(delivery.date).includes(:member)
          panel link_to("#{Absence.model_name.human(count: 2)} (#{absences.count})", absences_path(q: { including_date: delivery.date }, scope: :all)) do
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
            row(:date) { l(delivery.date, format: :long) }
            row(:note) { text_format(delivery.note) }
          end
        end

        if Current.org.feature?("shop")
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

        if Current.org.feature?("basket_content")
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
    render partial: "bulk_dates", locals: { f: f, resource: resource, context: self }
    if f.object.new_record? && BasketComplement.kept.any?
      f.inputs do
        f.input :basket_complements,
          as: :check_boxes,
          wrapper_html: { class: "legend-title" },
          collection: admin_basket_complements_collection,
          hint: true

        handbook_button(self, "deliveries", anchor: "complments-de-panier")
      end
    end
    f.inputs t(".details") do
      f.input :note, as: :text, input_html: { rows: 3 }
    end
    if Current.org.feature?("shop")
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
          required: false,
          collection: admin_depots_collection,
          input_html: {
            data: { form_checkbox_toggler_target: "input" }
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

  batch_action :open_shop, if: proc { Current.org.feature?("shop") && (!params[:scope] || params[:scope] == "coming") } do |selection|
    Delivery.where(id: selection).update_all(shop_open: true)
    redirect_back fallback_location: collection_path
  end

  batch_action :close_shop, if: proc { Current.org.feature?("shop") && (!params[:scope] || params[:scope] == "coming") } do |selection|
    Delivery.where(id: selection).update_all(shop_open: false)
    redirect_back fallback_location: collection_path
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
            disposition: "inline"
        end
      end
    end
  end

  config.batch_actions = true
  config.sort_order = "date_asc"
  config.per_page = 52
end
