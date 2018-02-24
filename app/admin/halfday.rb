ActiveAdmin.register Halfday do
  menu parent: '½ Journées', priority: 2, label: 'Dates'
  actions :all, except: [:show]

  scope :past
  scope :coming,  default: true

  includes :participations
  index do
    column :date, ->(h) { l h.date, format: :medium }, sortable: :date
    column :period, ->(h) { h.period }
    column :place, ->(h) { display_place(h) }
    column :activity, ->(h) { h.activity }
    column 'Participants', ->(h) {
      text = [h.participations.sum(&:participants_count), h.participants_limit || '∞'].join(' / ')
      link_to text, halfday_participations_path(q: { halfday_id_eq: h.id }, scope: :all)
    }
    actions
  end

  filter :place, as: :select, collection: -> { Halfday.distinct.pluck(:place).sort }
  filter :activity, as: :select, collection: -> { Halfday.distinct.pluck(:activity).sort }
  filter :date

  form do |f|
    f.inputs 'Date et horaire' do
      f.input :date, as: :datepicker, include_blank: false
      f.input :start_time, as: :time_select, include_blank: false, minute_step: 30
      f.input :end_time, as: :time_select, include_blank: false, minute_step: 30
    end
    f.inputs 'Lieu et activité' do
      if HalfdayPreset.any?
        f.input :preset_id,
          collection: HalfdayPreset.all + [HalfdayPreset.new(id: 0, place: 'Autre')],
          include_blank: false
      end
      preset_present = !!f.object.preset
      f.input :place, input_html: { disabled: preset_present }
      f.input :place_url, input_html: { disabled: preset_present }
      f.input :activity, input_html: { disabled: preset_present }
    end
    f.inputs 'Détails' do
      f.input :description, input_html: { rows: 5 }
      f.input :participants_limit, as: :number
    end
    f.actions
  end

  permit_params *%i[
    date
    start_time
    end_time
    preset_id
    place
    place_url
    activity
    description
    participants_limit
  ]

  before_build do |halfday|
    halfday.preset_id ||= HalfdayPreset.first&.id
    halfday.date ||= Date.current
  end

  controller do
    def create
      overwrite_date_of_time_params
      super do |format|
        redirect_to collection_url and return if resource.valid?
      end
    end

    def update
      overwrite_date_of_time_params
      super do |format|
        redirect_to collection_url and return if resource.valid?
      end
    end

    def overwrite_date_of_time_params
      date = Date.parse(params['halfday']["date"])
      params['halfday']["start_time(1i)"] = date.year.to_s
      params['halfday']["start_time(2i)"] = date.month.to_s
      params['halfday']["start_time(3i)"] = date.day.to_s
      params['halfday']["end_time(1i)"] = date.year.to_s
      params['halfday']["end_time(2i)"] = date.month.to_s
      params['halfday']["end_time(3i)"] = date.day.to_s
    rescue ArgumentError
    end
  end

  config.per_page = 25
  config.sort_order = 'date_asc'
end
