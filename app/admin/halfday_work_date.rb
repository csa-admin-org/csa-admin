ActiveAdmin.register HalfdayWorkDate do
  menu parent: 'Autre', priority: 20

  scope :past
  scope :coming,  default: true

  index_title = -> { "Date ½ Journées de travail (#{I18n.t("active_admin.scopes.#{current_scope.name.gsub(' ', '_').downcase}").downcase})" }

  index title: index_title do
    column :date, ->(halfday_work_date) { l halfday_work_date.date, format: :long }
    column :periods, ->(halfday_work_date) { halfday_work_date.periods.join(' + ') }
    actions
  end

  filter :date

  form do |f|
    f.inputs 'Details' do
      years_range = Basket.years_range
      f.input :date,
        start_year: years_range.first,
        end_year: years_range.last,
        include_blank: false
      f.input :period_am, as: :boolean, label: 'AM'
      f.input :period_pm, as: :boolean, label: 'PM'
    end
    f.actions
  end

  show do |halfday_work_date|
    attributes_table do
      row(:date) { l halfday_work_date.date, format: :long }
      row(:periods) { halfday_work_date.periods.join(' + ') }
    end
  end

  permit_params *%i[date period_am period_pm]

  controller do
    def create
      super do |format|
        redirect_to collection_url and return if resource.valid?
      end
    end

    def update
      super do |format|
        redirect_to collection_url and return if resource.valid?
      end
    end
  end

  config.per_page = 25
  config.sort_order = 'date_asc'
end
