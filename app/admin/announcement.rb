# frozen_string_literal: true

ActiveAdmin.register Announcement do
  menu parent: :other, priority: 3
  actions :all, except: [ :show ]


  scope :all
  scope :active, default: true
  scope :past

  filter :depots, as: :select, collection: -> { admin_depots_collection }
  filter :deliveries, as: :select, collection: -> { Delivery.all }

  index(
    download_links: false,
    title: -> { "#{Announcement.model_name.human(count: 2)} (#{Delivery.human_attribute_name(:sheets)})" }) do
    column :text, ->(a) { simple_format(a.text) }
    column :depots, ->(a) { display_objects(a.depots) }
    column Announcement.human_attribute_name(:future_deliveries), ->(a) {
      display_objects(a.coming_deliveries)
    }
    actions
  end

  sidebar :info, only: :index do
    div class: "panel text-sm p-4 rounded-sm b text-gray-800 dark:bg-gray-800 dark:text-gray-200" do
      t(".announcement_info")
    end
  end

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
        for: Depot,
        required: true,
        label: Depot.model_name.human(count: 2)
      if Delivery.current_year.any?
        f.input :delivery_ids,
          as: :check_boxes,
          for: Delivery,
          collection: Delivery.current_year.coming,
          label: Announcement.human_attribute_name(:current_deliveries)
      end
      if Delivery.future_year.any?
        f.input :delivery_ids,
          as: :check_boxes,
          for: Delivery,
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
