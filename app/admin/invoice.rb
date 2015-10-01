ActiveAdmin.register Invoice do
  menu priority: 4

  scope :all, default: true
  scope :open
  scope :closed

  scope :diff_name
  scope :diff_zip, group: 2

  index_title = -> { "Factures (#{I18n.t("active_admin.scopes.#{current_scope.name.gsub(' ', '_').downcase}").downcase})" }

  index title: index_title do
    column :number
    column :date
    column :member
    column :amount, ->(invoice) { number_to_currency(invoice.amount) }
    column :balance, ->(invoice) { number_to_currency(invoice.balance) }
    column :status, ->(invoice) { invoice.display_status }
    actions
  end

  sidebar 'Dernière mise à jour', only: :index do
    l Invoice.maximum(:updated_at).in_time_zone
  end

  filter :member,
    as: :select,
    collection: -> { Member.joins(:invoices).order(:last_name).distinct }
  filter :date

  show do |invoice|
    attributes_table do
      row :number
      row :member
      row(:date) { l invoice.date }
      row(:amount) { number_to_currency(invoice.amount) }
      row(:balance) { number_to_currency(invoice.balance) }
      row(:status) { invoice.display_status }
      row(:updated_at) { l invoice.updated_at }
    end

    panel "Données Facture côté compta. <em>(vs nos données)</em>".html_safe do
      attributes_table_for invoice do
        row(:name) { "#{invoice.data['first_name']} #{invoice.data['last_name']} <em>(vs #{invoice.member.name})</em>".html_safe }
        row(:zip) { "#{invoice.data['zip']} <em>(vs #{invoice.member.zip})</em>".html_safe }
        row(:city) { "#{invoice.data['city']} <em>(vs #{invoice.member.city})</em>".html_safe }
      end
    end
  end

  controller do
    def scoped_collection
      Invoice.includes(:member)
    end
  end

  config.per_page = 50
  config.sort_order = 'date_asc'
end
