# frozen_string_literal: true

module ActivitiesHelper
  def display_activity?
    feature?("activity")
  end

  def activity_human_name
    I18n.t("activities.#{Current.org.activity_i18n_scope}.one")
  end

  def activities_human_name
    I18n.t("activities.#{Current.org.activity_i18n_scope}.other")
  end

  def activities_collection(activities, data: {})
    activities.map do |activity|
      text = content_tag(:span, class: "activity-choice#{' is-booked' if activity.full?}") {
        content_tag(:span, class: "activity-choice-row") do
          activity_label(activity).html_safe
        end
      }.concat(
        content_tag(:span, class: "activity-choice-meta#{' is-booked' if activity.full?}", title: t("activities.participant_count", count: activity.participants_count)) {
          content_tag(:span, class: "activity-choice-meta-count") {
            "#{activity.participants_count}/#{activity.participants_limit || '∞'}"
          }.concat(icon("users", class: "activity-choice-meta-icon"))
        })
      [
        text,
        activity.id,
        data: {
          date: activity.date.to_s
        }.merge(data)
      ]
    end
  end

  def activities_titles_options(activities)
    titles = [ [ t("activities.all_titles"), nil ] ]
    activities.sort_by(&:title).group_by(&:title).each { |title, activities|
      titles << [
        truncate(title, length: 60),
        activities.map { |a| a.date.to_s }.uniq.sort.join(", ")
      ]
    }
    options_for_select(titles)
  end

  def activity_label(activity, date: false, date_format: :medium, description: true)
    labels = [
      content_tag(:span, activity.period, class: "activity-choice-period"),
      content_tag(:span) {
        [
          display_activity(activity, description: description),
          display_place(activity)
        ].join(", ").html_safe
      }
    ]
    labels.insert(0, l(activity.date, format: date_format).capitalize) if date
    labels.join(content_tag(:span, ",&nbsp;".html_safe, class: "activity-choice-sep"))
  end

  def display_place(activity)
    if activity.place_url
      link_to(activity.place, activity.place_url, target: :blank)
    else
      activity.place
    end
  end

  def display_activity(activity, description: true)
    if description && activity.description
      content_tag(:span, class: "activity-choice-title-wrap") {
        content_tag(:span, class: "activity-choice-title") {
          content_tag(:span, activity.title) +
            tooltip("activity-#{activity.id}", activity.description)
        }
      }
    else
      activity.title
    end
  end
end
