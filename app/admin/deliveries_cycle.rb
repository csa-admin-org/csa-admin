ActiveAdmin.register DeliveriesCycle do
  menu parent: :other, priority: 11, label: -> { t('deliveries_cycle.menu_title') }

  scope :all, default: true
  scope :visible
  scope :hidden

  filter :name_contains,
    label: -> { DeliveriesCycle.human_attribute_name(:name) },
    as: :string
  filter :depots, as: :select

  includes :depots
  index download_links: false do
    column :name, ->(dc) { auto_link dc }
    column :next_delivery, ->(dc) { auto_link dc.next_delivery }
    column Current.acp.current_fiscal_year, ->(dc) {
      auto_link dc, dc.current_deliveries.count
    }
    column Current.acp.fiscal_year_for(1.year.from_now), ->(dc) {
      auto_link dc, dc.future_deliveries.count
    }
    column :visible
    actions class: 'col-actions-3'
  end

  sidebar_handbook_link('deliveries#cycles-de-livraisons')

  show do |dc|
    columns do
      column do
        panel  "#{deliveries_current_year_title}: #{dc.current_deliveries.count}" do
          if dc.current_deliveries.any?
            table_for dc.current_deliveries, class: 'deliveries' do
              column '#', ->(d) { auto_link d, d.number }
              column :date, ->(d) { auto_link d, l(d.date, format: :medium_long) }
            end
          else
            span I18n.t("active_admin.empty"), class: "empty"
          end
        end
        panel "#{deliveries_next_year_title}: #{dc.future_deliveries.count}"  do
          if dc.future_deliveries.any?
            table_for dc.future_deliveries, class: 'deliveries' do
              column '#', ->(d) { auto_link d, d.number }
              column :date, ->(d) { auto_link d, l(d.date, format: :medium_long) }
            end
          else
            span I18n.t("active_admin.empty"), class: "empty"
          end
        end
      end

      column do
        attributes_table do
          row :name
          row :public_name
        end

        attributes_table title: t('.member_new_form') do
          row :form_priority
          row :visible
        end

        attributes_table title: t('deliveries_cycle.settings') do
          row(:wdays) {
            if dc.wdays.size == 7
              t('active_admin.scopes.all')
            else
              dc.wdays.map { |d| I18n.t('date.day_names')[d].capitalize }.to_sentence
            end
          }
          row(:week_numbers) { I18n.t("deliveries_cycle.week_numbers.#{dc.week_numbers}") }
          row(:months) {
            if dc.months.size == 12
              t('active_admin.scopes.all')
            else
              dc.months.map { |m| I18n.t('date.month_names')[m].capitalize }.to_sentence
            end
          }
          row(:results) { I18n.t("deliveries_cycle.results.#{dc.results}") }
        end

        panel Depot.model_name.human(count: 2) do
          table_for dc.depots, class: 'depots' do
            column :name, ->(d) { auto_link d }
            column :visible
          end
        end

        active_admin_comments
      end
    end
  end

  form do |f|
    f.inputs do
      translated_input(f, :names, required: true)
      translated_input(f, :public_names,
        required: false,
        hint: t('formtastic.hints.deliveries_cycle.public_name'))
    end

    f.inputs t('active_admin.resource.show.member_new_form') do
      f.input :form_priority, hint: true
      f.input :visible, as: :select, include_blank: false
    end

    f.inputs t('deliveries_cycle.settings') do
      f.input :wdays,
        as: :check_boxes,
        collection: wdays_collection,
        required: true
      f.input :week_numbers,
        as: :select,
        collection: week_numbers_collection,
        include_blank: false
      f.input :months,
        as: :check_boxes,
        collection: months_collection,
        required: true
      f.input :results,
        as: :select,
        collection: results_collection,
        include_blank: false
    end

    f.inputs do
      f.input :depots,
        as: :check_boxes,
        disabled: depot_ids_with_only(f.object)
    end

    f.actions
  end

  permit_params(
    :visible,
    :form_priority,
    :week_numbers,
    :results,
    *I18n.available_locales.map { |l| "name_#{l}" },
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    wdays: [],
    months: [],
    depot_ids: [])

  controller do
    include DeliveriesCyclesHelper

    private

    def assign_attributes(resource, attributes)
      if attributes.first[:depot_ids]
        attributes.first[:depot_ids] += depot_ids_with_only(resource).map(&:to_s)
        attributes.first[:depot_ids].uniq!
      end
      super(resource, attributes)
    end
  end

  config.sort_order = :default_scope
end
