ActiveAdmin.register Halfday do
  menu parent: :halfdays_human_name, priority: 2, label: Halfday.human_attribute_name(:dates)
  actions :all, except: [:show]

  scope :all
  scope :past
  scope :coming, default: true

  includes :participations
  index do
    column :date, ->(h) { l h.date, format: :medium }, sortable: :date
    column :period, ->(h) { h.period }
    column :place, ->(h) { display_place(h) }
    column :activity, ->(h) { h.activity }
    column :participants, ->(h) {
      text = [h.participations.sum(&:participants_count), h.participants_limit || '∞'].join(' / ')
      link_to text, halfday_participations_path(q: { halfday_id_eq: h.id }, scope: :all)
    }
    actions
  end

  csv do
    column(:date)
    column(:period)
    column(:place)
    column(:place_url)
    column(:activity)
    column(:description)
    column(:participants) { |h| h.participations.sum(&:participants_count) }
    column(:participants_limit)
  end

  filter :place, as: :select, collection: -> { Halfday.select(:places).distinct.map(&:place).sort }
  filter :activity, as: :select, collection: -> { Halfday.select(:activities).distinct.map(&:activity).sort }
  filter :date

  form do |f|
    f.inputs t('formtastic.inputs.date_and_period') do
      f.input :date, as: :datepicker
      f.input :start_time, as: :time_select, include_blank: false, minute_step: 30
      f.input :end_time, as: :time_select, include_blank: false, minute_step: 30
    end
    f.inputs t('formtastic.inputs.place_and_activity') do
      if HalfdayPreset.any? && f.object.new_record?
        f.input :preset_id,
          collection: HalfdayPreset.all + [HalfdayPreset.new(id: 0, place: HalfdayPreset.human_attribute_name(:other))],
          include_blank: false
      end
      preset_present = f.object.preset.present?
      translated_input(f, :places, input_html: { disabled: preset_present, class: 'js-preset' })
      translated_input(f, :place_urls, input_html: { disabled: preset_present, class: 'js-preset' })
      translated_input(f, :activities, input_html: { disabled: preset_present, class: 'js-preset' })
    end
    f.inputs t('.details') do
      translated_input(f, :descriptions, as: :text, required: false, input_html: { rows: 5 })
      f.input :participants_limit, as: :number
    end
    f.actions
  end

  permit_params(
    :date, :start_time, :end_time,
    :preset_id, :participants_limit,
    places: I18n.available_locales,
    place_urls: I18n.available_locales,
    activities: I18n.available_locales,
    descriptions: I18n.available_locales)

  before_build do |halfday|
    halfday.preset_id ||= HalfdayPreset.first&.id
    halfday.date ||= Date.current
  end

  controller do
    def create
      overwrite_date_of_time_params
      super
    end

    def update
      overwrite_date_of_time_params
      super
    end

    def overwrite_date_of_time_params
      date = Date.parse(params['halfday']['date'])
      params['halfday']['start_time(1i)'] = date.year.to_s
      params['halfday']['start_time(2i)'] = date.month.to_s
      params['halfday']['start_time(3i)'] = date.day.to_s
      params['halfday']['end_time(1i)'] = date.year.to_s
      params['halfday']['end_time(2i)'] = date.month.to_s
      params['halfday']['end_time(3i)'] = date.day.to_s
    rescue ArgumentError
    end
  end

  config.per_page = 25
  config.sort_order = 'date_asc'
end
