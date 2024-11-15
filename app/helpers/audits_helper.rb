# frozen_string_literal: true

module AuditsHelper
  def display_change_of(attr, change, **opts)
    return content_tag(:span, t("active_admin.empty"), class: "attributes-table-empty-value !text-sm") if change.blank?

    case attr
    when "state"
      content_tag(:span, t("states.member.#{change}"), class: "status-tag", data: { status: change })
    when "shop_depot_id"
      if depot = Depot.find_by(id: change)
        auto_link depot
      else
        content_tag(:span, t("active_admin.unknown"), class: "attributes-table-empty-value !text-sm")
      end
    else
      case change
      when true, false
        content_tag(:span, t("active_admin.status_tag.#{change}"), class: "status-tag", data: { status: change ? "yes" : "no" })
      else
        content_tag(:span, change, **opts)
      end
    end
  end
end
