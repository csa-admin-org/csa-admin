ActiveAdmin.register Announcement do
  menu parent: :other, priority: 3
  actions :all, except: [:show]

  filter :depots, as: :select, collection: -> { Depot.all }
  filter :deliveries, as: :select, collection: -> { Delivery.all }

  index(
    download_links: false,
    title: -> { "#{Announcement.model_name.human(count: 2)} (#{Delivery.human_attribute_name(:signature_sheets)})" })do
    column :text, ->(a) { a.text }
    column :depots, ->(a) {
      truncate(
        a.depots.map { |d|
          link_to(d.name, d)
        }.to_sentence.html_safe,
        length: 250,
        escape: false)
    }
    column Announcement.human_attribute_name(:future_deliveries), ->(a) {
      truncate(
        a.coming_deliveries.map { |d|
          link_to(d.display_name, d)
        }.to_sentence.html_safe,
        length: 250,
        escape: false).presence || '–'
    }
    if authorized?(:update, Announcement)
      actions class: 'col-actions-2'
    end
  end

  form do |f|
    f.semantic_errors :base
    f.inputs do
      translated_input(f, :texts,
        hint: t('formtastic.hints.annoucement.text'))
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
