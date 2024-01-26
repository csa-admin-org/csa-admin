ActiveAdmin.register Announcement do
  menu parent: :other, priority: 3
  actions :all, except: [ :show ]

  filter :depots, as: :select, collection: -> { Depot.all }
  filter :deliveries, as: :select, collection: -> { Delivery.all }

  index(
    download_links: false,
    title: -> { "#{Announcement.model_name.human(count: 2)} (#{Delivery.human_attribute_name(:sheets)})" }) do
    column :text, ->(a) { simple_format(a.text) }
    column :depots, ->(a) { display_objects(a.depots) }
    column Announcement.human_attribute_name(:future_deliveries), ->(a) {
      display_objects(a.coming_deliveries)
    }
    if authorized?(:update, Announcement)
      actions class: "col-actions-2"
    end
  end

  sidebar :info, only: :index do
    div class: "content" do
      t(".announcement_info")
    end
  end

  form do |f|
    f.semantic_errors :base
    f.inputs do
      translated_input(f, :texts,
        as: :text,
        input_html: { rows: 4, cols: 32 } ,
        hint: t("formtastic.hints.announcement.text_html"))
      f.input :depot_ids,
        collection: Depot.all,
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
