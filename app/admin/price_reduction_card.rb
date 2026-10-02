# frozen_string_literal: true

ActiveAdmin.register PriceReductionCard do
  menu false

  breadcrumb do
    links = [
      link_to(PriceReduction.model_name.human(count: 2), price_reductions_path)
    ]
    unless params["action"] == "index"
      links << link_to(PriceReductionCard.model_name.human(count: 2), price_reduction_cards_path)
    end
    links << resource.name if params[:action] == "edit"
    links
  end

  actions :all, except: [ :show ]

  sidebar :info, only: :index do
    page = Handbook.new("price_reductions", nil)
    action = handbook_icon_link("price_reductions", anchor: "cards") if page.filepath.exist?
    side_panel t(".info"), action: action do
      para t(".price_reduction_card_info")
    end
  end

  index download_links: false do
    column :name, ->(card) { link_to card.name, [ :edit, card ] }, sortable: true
    column :required_fields, ->(card) { card.required_fields_sentence }, sortable: false
    actions
  end

  form do |f|
    f.inputs do
      translated_input(f, :names)
      f.input :required_fields,
        as: :check_boxes,
        wrapper_html: { class: "single-column" },
        collection: PriceReductionCard::REQUIRED_FIELDS.map { |field|
          [ PriceReductionCard.human_attribute_name("required_field/#{field}"), field ]
        },
        required: true,
        hint: true
    end
    f.actions
  end

  permit_params(
    *I18n.available_locales.map { |locale| "name_#{locale}" },
    required_fields: [])

  order_by(:name) do |clause|
    config
      .resource_class
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.filters = false
  config.sort_order = "name_asc"
end
