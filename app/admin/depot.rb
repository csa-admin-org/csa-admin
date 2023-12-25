ActiveAdmin.register Depot do
  menu parent: :other, priority: 5

  scope :all
  scope :visible, default: true
  scope :hidden

  filter :name_cont,
    label: -> { Depot.human_attribute_name(:name) },
    as: :string
  filter :city_cont,
    label: -> { Depot.human_attribute_name(:city) },
    as: :string
  filter :delivery_cycles, as: :select

  includes :memberships, :delivery_cycles
  index do
    column :id, ->(d) { auto_link d, d.id }
    column :name, ->(d) { link_to display_name_with_public_name(d), d }
    column :city
    if Depot.pluck(:price).any?(&:positive?)
      column :price, ->(d) { cur(d.price) }
    end
    if DeliveryCycle.visible?
      column :delivery_cycles, ->(d) {
        d.delivery_cycles.map { |cycle|
          auto_link cycle, "#{cycle.name} (#{cycle.deliveries_count})"
        }.join(', ').html_safe
      }
    end
    column :visible
    actions class: 'col-actions-3'
  end

  member_action :move_to, method: :patch do
    authorize!(:update, Depot)
    depot = Depot.find(params[:id])
    delivery = Delivery.find(params[:delivery_id])
    depot.move_to(params[:position].to_i, delivery)
    head :ok
  end

  member_action :move_member_to, method: :patch do
    authorize!(:update, Depot)
    depot = Depot.find(params[:id])
    member = Member.find(params[:member_id])
    delivery = Delivery.find(params[:delivery_id])
    depot.move_member_to(params[:position].to_i, member, delivery)
    head :ok
  end

  csv do
    column(:id)
    column(:name)
    column(:public_name)
    if Current.acp.languages.many?
      column(:language) { |d| t("languages.#{d.language}") }
    end
    column(:price) { |d| cur(d.price) }
    column(:note)
    column(:address_name)
    column(:address)
    column(:zip)
    column(:visible)
    column(:contact_name)
    column(:emails) { |d| d.emails_array.join(', ') }
    column(:phones) { |d| d.phones_array.map(&:phony_formatted).join(', ') }
  end

  show do |depot|
    columns do
      column do
        if next_delivery = depot.next_delivery
          panel t('active_admin.page.index.next_delivery', delivery: link_to(next_delivery.display_name(format: :long), next_delivery)).html_safe do
            div class: 'actions' do
              icon_link(:xlsx_file, Delivery.human_attribute_name(:summary), delivery_path(next_delivery, format: :xlsx, depot_id: depot.id)) +
              icon_link(:pdf_file, Delivery.human_attribute_name(:sheets), delivery_path(next_delivery, format: :pdf, depot_id: depot.id), target: '_blank')
            end

            attrs = {}
            if authorized?(:update, depot) && depot.delivery_sheets_mode == 'home_delivery'
              attrs[:class] = 'sortable'
              attrs[:tbody] = { 'data-controller' => 'sortable' }
              attrs[:row_data] = ->(b) {
                { 'data-sortable-update-url' => "/depots/#{b.depot_id}/move_member_to?delivery_id=#{b.delivery_id}&member_id=#{b.member.id}" }
              }
            end

            table_for(depot.baskets_for(next_delivery), **attrs) do
              column Member.model_name.human, -> (b) { auto_link b.member }
              column Basket.model_name.human, -> (b) { link_to(b.description, b.membership) }
            end
          end
        else
          panel t('active_admin.page.index.no_next_delivery') do
            div class: 'blank_slate_container' do
              i do
                link_to t('active_admin.page.index.no_next_deliveries'), deliveries_path
              end
            end
          end
        end
      end
      column do
        attributes_table do
          row :id
          row :name
          row :public_name
          if Current.acp.languages.many?
            row(:language) { t("languages.#{depot.language}") }
          end
          row(:price) { cur(depot.price) }
          row(:note) { text_format(depot.note) }
          row(:public_note) { depot.public_note if depot.public_note? }
        end

        attributes_table title: Delivery.human_attribute_name(:sheets_pdf) do
          row(:delivery_sheets_mode) { t("delivery.sheets_mode.#{depot.delivery_sheets_mode}") }
        end

        attributes_table title: t('.member_new_form') do
          row :visible
          if DeliveryCycle.visible?
            table_for depot.delivery_cycles, class: 'delivery_cycles' do
              column DeliveryCycle.model_name.human, ->(dc) { auto_link dc }
              column Current.acp.current_fiscal_year, ->(dc) {
                auto_link dc, dc.current_deliveries_count
              }
              column Current.acp.fiscal_year_for(1.year.from_now), ->(dc) {
                auto_link dc, dc.future_deliveries_count
              }
            end
          end
        end

        attributes_table title: Depot.human_attribute_name(:address) do
          row :address_name
          row :address
          row :zip
          row :city
        end

        attributes_table title: Depot.human_attribute_name(:contact) do
          row :contact_name
          row(:emails) { display_emails_with_link(self, depot.emails_array) }
          row(:phones) { display_phones_with_link(self, depot.phones_array) }
        end


        active_admin_comments
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      translated_input(f, :public_names,
        required: false,
        hint: t('formtastic.hints.depot.public_name'))
      language_input(f)
      f.input :price, hint: true
      f.input :note, input_html: { rows: 3 }
      translated_input(f, :public_notes,
        as: :action_text,
        required: false,
        hint: t('formtastic.hints.depot.public_note'))
    end

    f.inputs Delivery.human_attribute_name(:sheets_pdf) do
      f.input :delivery_sheets_mode,
        as: :radio,
        wrapper_html: { class: 'detailed-option' },
        collection: Depot::DELIVERY_SHEETS_MODES.map { |mode|
          [
            content_tag(:span) {
              content_tag(:span, t("delivery.sheets_mode.#{mode}")) +
              content_tag(:span, t("delivery.sheets_mode.#{mode}_hint").html_safe, class: 'hint')
            },
            mode
          ]
        }
    end

    f.inputs t('active_admin.resource.show.member_new_form') do
      f.input :visible, as: :select, include_blank: false
      f.input :member_order_priority,
        collection: member_order_priorities_collection,
        as: :select,
        prompt: true,
        hint: t('formtastic.hints.acp.member_order_priority_html')
      unless DeliveryCycle.basket_size_config?
        f.input :delivery_cycles,
          collection: delivery_cycles_collection,
          input_html: f.object.persisted? ? {} : { checked: true },
          as: :check_boxes,
          required: true
      end
    end

    f.inputs Depot.human_attribute_name(:address) do
      f.input :address_name
      f.input :address
      f.input :city
      f.input :zip
    end

    f.inputs Depot.human_attribute_name(:contact) do
      f.input :contact_name
      f.input :emails, as: :string
      f.input :phones, as: :string
    end

    f.actions
  end

  permit_params(
    *%i[
      name language price visible note
      address_name address zip city
      contact_name emails phones
      member_order_priority
      delivery_sheets_mode
    ],
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "public_note_#{l}" },
    delivery_cycle_ids: [])

  before_build do |depot|
    depot.price ||= 0.0
  end

  controller do
    include TranslatedCSVFilename
    include DeliveryCyclesHelper
  end

  config.sort_order = 'name_asc'
  config.paginate = false
end
