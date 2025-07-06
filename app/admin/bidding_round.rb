# frozen_string_literal: true

ActiveAdmin.register BiddingRound do
  menu parent: :other, priority: 9
  actions :all

  scope :all, default: true
  scope :draft
  scope :open
  scope :completed
  scope :failed

  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  index(download_links: false) do
    column :title
    column :state, ->(br) { status_tag(br.state) }
    actions
  end

  sidebar_handbook_link("bidding_round")

  form do |f|
    if f.object.errors.any?
      div class: "mb-6" do
        f.object.errors.attribute_names.each do |attr|
          para f.semantic_errors attr
        end
      end
    end

    f.inputs t(".details") do
      translated_input(f, :texts,
        as: :text,
        input_html: { rows: 4, cols: 32 },
        hint: t("formtastic.hints.announcement.text_html"))
      f.input :depot_ids,
        collection: admin_depots,
        as: :check_boxes,
        required: true,
        label: Depot.model_name.human(count: 2)
      if Delivery.current_year.any?
        f.input :delivery_ids,
          as: :check_boxes,
          collection: Delivery.current_year.coming,
          label: Announcement.human_attribute_name(:current_deliveries)
      end
      if Delivery.future_year.any?
        f.input :delivery_ids,
          as: :check_boxes,
          collection: Delivery.future_year,
          label: Announcement.human_attribute_name(:future_deliveries)
      end
    end
    f.actions
  end

  permit_params(
    *I18n.available_locales.map { |l| "text_#{l}" },
    depot_ids: [],
    delivery_ids: [])
end
