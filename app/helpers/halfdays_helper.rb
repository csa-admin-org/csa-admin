module HalfdaysHelper
  def halfday_human_name
    I18n.t("halfdays.#{Current.acp.halfday_i18n_scope}.one")
  end

  def halfdays_human_name
    I18n.t("halfdays.#{Current.acp.halfday_i18n_scope}.other")
  end

  def t_halfday(key, *options)
    t(halfday_scoped_attribute(key), *options)
  end

  def halfday_scoped_attribute(attr)
    "#{attr}/#{Current.acp.halfday_i18n_scope}".to_sym
  end

  def halfday_label(halfday, date: false, date_format: :medium, description: true)
    labels = [
      halfday.period,
      display_place(halfday),
      display_activity(halfday, description: description)
    ]
    labels.insert(0, l(halfday.date, format: date_format).capitalize) if date
    labels.join(', ')
  end

  def display_place(halfday)
    if halfday.place_url
      link_to(halfday.place, halfday.place_url, target: :blank)
    else
      halfday.place
    end
  end

  def display_activity(halfday, description: true)
    if description && halfday.description
      halfday.activity +
        content_tag(:span, class: 'tooltip-toggle', data: { tooltip: halfday.description }) {
          content_tag :i, nil, class: 'fa fa-info-circle'
        }
    else
      halfday.activity
    end
  end

  def halfday_participation_summary(halfday_participation)
    summary = halfday_participation.member.name
    if halfday_participation.participants_count > 1
      summary << " (#{halfday_participation.participants_count})"
    end
    if halfday_participation.pending? || halfday_participation.rejected? || halfday_participation.validated?
      summary << " [#{halfday_participation.state_i18n_name}]"
    end
    summary
  end
end
