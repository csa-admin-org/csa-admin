ActiveAdmin.register Distribution do
  menu parent: :other, priority: 10

  includes :responsible_member
  index download_links: false do
    column :name, ->(d) { auto_link d }
    column :address
    column :zip
    column :city
    if Distribution.pluck(:price).any?(&:positive?)
      column :price, ->(d) { number_to_currency(d.price) }
    end
    column :responsible_member
    actions
  end

  show do |distribution|
    attributes_table do
      row :name
      if Current.acp.languages.many?
        row(:language) { t("languages.#{distribution.language}") }
      end
      row(:price) { number_to_currency(distribution.price) }
      row(:note) { simple_format distribution.note }
    end

    attributes_table title: Distribution.human_attribute_name(:address) do
      row :address_name
      row :address
      row :zip
      row :city
    end

    attributes_table title: Distribution.human_attribute_name(:contact) do
      row(:emails) { display_emails(distribution.emails_array) }
      row(:phones) { display_phones(distribution.phones_array) }
      row :responsible_member
    end

    active_admin_comments
  end

  form do |f|
    f.inputs do
      f.input :name
      if Current.acp.languages.many?
        f.input :language,
          as: :select,
          collection: Current.acp.languages.map { |l| [t("languages.#{l}"), l] },
          include_blank: false
      end
      f.input :price, hint: true
      f.input :note, input_html: { rows: 3 }
    end

    f.inputs Distribution.human_attribute_name(:address) do
      f.input :address_name
      f.input :address
      f.input :city
      f.input :zip
    end

    f.inputs Distribution.human_attribute_name(:contact) do
      f.input :emails
      f.input :phones
      f.input :responsible_member, collection: Member.order(:name)
    end

    f.actions
  end

  permit_params(*%i[
    name language price note
    address_name address zip city
    emails phones responsible_member_id
  ])

  before_build do |distribution|
    distribution.price ||= 0.0
  end

  config.filters = false
  config.per_page = 25
  config.sort_order = 'name_asc'
end
