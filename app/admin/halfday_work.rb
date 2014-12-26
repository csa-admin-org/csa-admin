ActiveAdmin.register HalfdayWork do
  menu priority: 4

  scope :waiting_validation, default: true
  scope :coming
  scope :validated
  scope :rejected

  index do
    selectable_column
    column :date
    column :member
    column :periods, ->(halfday_work) { halfday_work.periods.join(' + ') }
    column :participants_count
    column :status, ->(halfday_work) {
      I18n.t("halfday_work.status.#{halfday_work.status}")
    }
    actions
  end

  filter :member
  filter :date

  form do |f|
    f.inputs 'Details' do
      years_range = Basket.years_range
      f.input :date, start_year: years_range.first, end_year: years_range.last, include_blank: false
      f.input :member, include_blank: false
      f.input :participants_count
      f.input :period_am, as: :boolean, label: 'AM'
      f.input :period_pm, as: :boolean, label: 'PM'
    end
    f.actions
  end

  batch_action :reject do |selection|
    HalfdayWork.find(selection).each do |halfday_work|
      halfday_work.reject!(current_admin)
    end
    redirect_to collection_path
  end

  batch_action :validate do |selection|
    HalfdayWork.find(selection).each do |halfday_work|
      halfday_work.validate!(current_admin)
    end
    redirect_to collection_path
  end

  controller do
    def scoped_collection
      HalfdayWork.includes(:member)
    end

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

  permit_params do
    %i[date member_id participants_count period_am period_pm]
  end

  config.per_page = 50
  config.batch_actions = true
end
