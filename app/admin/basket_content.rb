# frozen_string_literal: true

ActiveAdmin.register BasketContent do
  menu \
    priority: 5,
    label: -> {
      [
        icon("shopping-bag", class: "size-5 -mt-0.5 mr-2.5 md:mr-2 inline"),
        Basket.model_name.human(count: 2)
      ].join.html_safe
    },
    url: -> { smart_basket_contents_path }

  breadcrumb do
    links = []
    case params[:action]
    when "new"
      links << link_to(BasketContent.model_name.human(count: 2), smart_basket_contents_path)
    when "edit"
      links << link_to(BasketContent.model_name.human(count: 2), basket_contents_path(q: { delivery_id_eq: resource.delivery_id }))
    end
    links
  end

  actions :all, except: [ :show ]

  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :delivery,
    as: :select,
    collection: -> { grouped_by_date(Delivery, past: :first) }
  filter :product, as: :select, collection: -> { basket_content_products_collection }
  filter :basket_size, as: :select, collection: -> { BasketSize.ordered.paid }
  filter :depots, as: :select, collection: -> { admin_depots_collection }

  includes :depots, :delivery, :product, :basketcontents_depots

  class BasketContentIndex < ActiveAdmin::Views::IndexAsTable
    def build(_page_presenter, collection)
      if params.dig(:q, :delivery_id_eq).present? && collection.with_unit_price.any?
        delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
        basket_content_prices = delivery.basket_content_prices
        if basket_content_prices.any?
          panel nil do
            render partial: "active_admin/basket_contents/prices", locals: { delivery: delivery, basket_content_prices: basket_content_prices, context: self }
          end
          return div class: "table-wrapper" do
            div class: "table-wrapper-content" do
              super
            end
          end
        end
      end
      super
    end
  end

  index as: BasketContentIndex, download_links: -> {
    params.dig(:q, :delivery_id_eq).present? ? [ :csv, :xlsx ] : [ :csv ]
  }, title: -> {
    title = BasketContent.model_name.human(count: 2)
    if params.dig(:q, :delivery_id_eq).present?
      delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
      title += " – #{delivery.display_name}"
    end
    title
  } do
    unless params.dig(:q, :delivery_id_eq).present?
      column :delivery, ->(bc) { I18n.l bc.delivery.date, format: :number }, class: "whitespace-nowrap", sortable: :delivery_date
    end
    column :product, ->(bc) {
      display_with_unit_price(bc.unit_price, bc.unit) {
        display_with_external_url(bc.product.name, bc.product.url)
      }
    }, class: "whitespace-nowrap", sortable: :product_name
    unless params.dig(:q, :basket_size_eq).present?
      column :qt, ->(bc) {
        display_with_price(bc.unit_price, bc.quantity) {
          display_total_quantity(bc)
        }
      }, class: "text-right whitespace-nowrap"
    end
    basket_sizes =
      if params.dig(:q, :basket_size_eq).present?
        BasketSize.ordered.paid.where(id: params.dig(:q, :basket_size_eq))
      elsif (delivery_id = params.dig(:q, :delivery_id_eq)).present?
        sizes =
          BasketSize
            .joins(:baskets)
            .where(baskets: { delivery_id: delivery_id })
            .distinct.paid.ordered
        sizes.any? ? sizes : BasketSize.ordered.paid
      else
        BasketSize.ordered.paid
      end
    basket_sizes.each do |basket_size|
      column basket_size.name, ->(bc) {
        display_with_price(bc.unit_price, bc.basket_quantity(basket_size)) {
          if authorized?(:update, bc) && params.dig(:q, :delivery_id_eq).present?
            display_basket_quantity_editable(bc, basket_size)
          else
            display_basket_quantity(bc, basket_size)
          end
        }
      }, class: "text-right whitespace-nowrap"
    end
    column :depots, ->(bc) { display_depots(bc.depots) }, class: "text-right"
    actions
  end

  action_item :product, only: :index do
    action_link BasketContent::Product.model_name.human(count: 2), basket_content_products_path, icon: "sprout"
  end

  csv do
    column(:date) { |bc| bc.delivery.date.to_s }
    column(:month) { |bc| t("date.month_names")[bc.delivery.date.month] }
    column(:wday) { |bc| t("date.day_names")[bc.delivery.date.wday] }
    column(:product) { |bc| bc.product.name }
    column(:unit) { |bc| t("units.#{bc.unit}.flex") }
    column(:unit_price) { |bc| cur(bc.unit_price) }
    column(:quantity) { |bc| bc.quantity }
    BasketSize.paid.ordered.each do |basket_size|
      column("#{basket_size.name} - #{Basket.model_name.human(count: 2)}") { |bc|
        bc.baskets_count(basket_size)
      }
      column("#{basket_size.name} - #{t("attributes.quantity")}") { |bc|
        bc.basket_quantity(basket_size)
      }
      column("#{basket_size.name} - #{BasketContent.human_attribute_name(:price)}") { |bc|
        display_price bc.unit_price, bc.basket_quantity(basket_size)
      }
    end
    column(:depots) { |bc| display_depots(bc.depots) }
  end

  sidebar :total, only: :index, if: -> {
    params.dig(:q, :product_id_eq).present? && params.dig(:q, :delivery_id_eq).blank?
  } do
    side_panel t(".total") do
      basket_contents = collection.offset(nil).limit(nil).to_a
      totals = basket_contents_totals(basket_contents)
      unit = basket_contents.first&.unit ||
        BasketContent::Product.find_by(id: params.dig(:q, :product_id_eq))&.unit

      div number_line(
        BasketContent.human_attribute_name(:basket_quantity),
        display_basket_contents_total_quantity(totals[:quantity], unit),
        bold: true)
      div number_line(
        BasketContent.human_attribute_name(:price),
        cur(totals[:price]),
        bold: false)
    end
  end

  sidebar :member_visibility, only: :index, if: -> {
    params.dig(:q, :delivery_id_eq).present? &&
      Delivery.find(params.dig(:q, :delivery_id_eq)).coming?
  } do
    t_scope = "active_admin.basket_contents.member_visibility"
    delivery = Delivery.find(params.dig(:q, :delivery_id_eq))

    settings_action = if authorized?(:update, Organization)
      link_to edit_organization_path(:basket_content), title: t("#{t_scope}.settings") do
        icon "sliders-horizontal", class: "size-5"
      end
    end

    if Current.org.basket_content_member_visible?
      side_panel t(".member_visibility"), action: settings_action do
        if Current.org.basket_content_visible_for_delivery?(delivery)
          para t("#{t_scope}.currently_visible")
        else
          visible_at = Current.org.basket_content_member_visible_at(delivery)
          para t("#{t_scope}.visible_on_html", datetime: I18n.l(visible_at, format: :short))
        end
      end
    else
      side_panel t(".member_visibility"), action: settings_action do
        para t("#{t_scope}.disabled"), class: "text-sm text-gray-500"
      end
    end
  end

  sidebar :duplicate_all_to, only: :index, if: -> {
    authorized?(:create, BasketContent)
      && params.dig(:q, :delivery_id_eq).present?
      && collection.present?
      && (delivery = Delivery.find(params.dig(:q, :delivery_id_eq)))
      && BasketContent.coming_deliveries_missing_contents_from(delivery).any?
  } do
    side_panel t(".duplicate_all_to") do
      delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
      render partial: "active_admin/basket_contents/duplicate_all_to",
        locals: { from_delivery: delivery }
    end
  end

  sidebar :duplicate_all_from, only: :index, if: -> {
    authorized?(:create, BasketContent)
      && params.dig(:q, :delivery_id_eq).present?
      && (delivery = Delivery.find(params.dig(:q, :delivery_id_eq)))
      && BasketContent.filled_deliveries_with_contents_missing_from(delivery).any?
  } do
    side_panel t(".duplicate_all_from") do
      delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
      render partial: "active_admin/basket_contents/duplicate_all_from",
        locals: { to_delivery: delivery }
    end
  end

  sidebar_handbook_link("basket_content")

  collection_action :duplicate_all, method: :post do
    authorize!(:create, BasketContent)
    from = params.require(:from_delivery_id)
    to = params.require(:to_delivery_id)
    BasketContent.duplicate_all(from, to)
    redirect_to basket_contents_path(q: { delivery_id_eq: to })
  end

  member_action :inline_update, method: :patch do
    basket_content = BasketContent.find(params[:id])
    authorize!(:update, basket_content)
    basket_size_id = params.require(:basket_size_id)

    # Build the full quantities hash preserving existing values
    quantities = basket_content.basket_size_ids.each_with_object({}) do |id, h|
      h[id.to_s] = basket_content.basket_size_ids_quantity(id).to_s
    end
    quantities[basket_size_id.to_s] = params[:quantity].to_i

    basket_content.basket_size_ids_quantities = quantities
    basket_content.save!

    redirect_back fallback_location: collection_path(q: { delivery_id_eq: basket_content.delivery_id })
  end

  form data: {
    controller: "basket-content-form",
    action: [
      "input->basket-content-form#formChanged",
      "change->basket-content-form#formChanged"
    ].join(" "),
    "basket-content-form-target" => "form"
  } do |f|
    f.object.apply_form_params!(params)
    render partial: "active_admin/basket_contents/form", locals: { f: f, context: self }
  end

  permit_params(*%i[delivery_id product_id unit_price],
    depot_ids: [],
    basket_size_ids_quantities: {})

  before_build do |basket_content|
    basket_content.delivery_id ||= smart_referer(:delivery_id) || Delivery.next&.id
    if params[:action] == "new" && basket_content.depots.empty?
      basket_content.depots = Depot.kept
    end
  end

  before_action only: :index do
    params[:q] ||= {}
    if delivery_id = params.dig(:q, :delivery_id_eq)
      if delivery = Delivery.find_by(id: delivery_id)
        fy_year = params.dig(:q, :during_year)
        if fy_year && fy_year.to_i != delivery.fy_year
          params[:q][:delivery_id_eq] = BasketContent.closest_delivery(fy_year)&.id
        else
          params[:q][:during_year] = delivery.fy_year
        end
      end
    elsif fy_year = params.dig(:q, :during_year)
      params[:q][:delivery_id_eq] = BasketContent.closest_delivery(fy_year)&.id
    end
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper
    include UncachedSendData

    helper_method :initial_distribution_data

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

    def create
      create! do |success, failure|
        success.html { redirect_to collection_path(q: { delivery_id_eq: resource.delivery_id }) }
      end
    end

    def update
      update! do |success, failure|
        success.html { redirect_to collection_path(q: { delivery_id_eq: resource.delivery_id }) }
      end
    end

    def scoped_collection
      super.joins(:delivery, :product)
    end

    private

    def initial_distribution_data(basket_content)
      distribution = basket_content.form_distribution_data(params)
      distribution[:depot_ids] ||= Depot.kept.pluck(:id)
      distribution[:depots] = Depot.kept.order_by_name
      distribution[:depot_groups] = helpers.admin_depots_grouped_collection
      distribution
    end
  end

  order_by(:product_name) do |clause|
    BasketContent::Product
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  order_by(:delivery_date) do |clause|
    Delivery
      .reorder(date: clause.order)
      .order_values
      .map(&:to_sql)
      .join(" ")
  end

  config.sort_order = "product_name_asc"
end
