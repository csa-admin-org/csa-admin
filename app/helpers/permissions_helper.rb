module PermissionsHelper
  def permission_rights_collection(permission, feature)
    Permission::RIGHTS.map { |r|
      [
        t("permissions.rights.#{r}"),
        r,
        { selected: permission.right(feature) == r }
      ]
    }
  end

  def display_rights(permission)
    if permission.superadmin?
      t("permissions.superadmin.description")
    else
      Permission
        .features
        .select { |f| permission.can_write?(f) }
        .map { |f| feature_name(f) }
        .sort
        .presence&.to_sentence || "–"
    end
  end

  def feature_name(feature)
    case feature
    when :acp
      t("active_admin.settings")
    when :comment
      ActiveAdmin::Comment.model_name.human(count: 2)
    when :activity
      activities_human_name
    when :billing
      t("billing.title")
    else
      if Current.acp.feature?(feature)
        t("features.#{feature}")
      else
        feature.to_s.classify.constantize.model_name.human(count: 2)
      end
    end
  end
end
