ActiveAdmin.register Admin do
  menu parent: :other, priority: 99

  includes :last_session
  index download_links: false do
    column :name
    column :email
    column :last_session_used_at, sortable: 'sessions.last_used_at'
    column :rights
    actions
  end

  show do |admin|
    attributes_table do
      row :name
      row :email
      if Current.acp.languages.many?
        row(:language) { t("languages.#{admin.language}") }
      end
      row :rights
      row :created_at
      row :last_session_used_at
      row(:notifications) {
        admin.notifications.map { |n| t("admin.notifications.#{n}") }.join(', ')
      }
    end
  end

  form do |f|
    f.inputs Admin.model_name.human do
      f.input :name
      f.input :email
      if Current.acp.languages.many?
        f.input :language,
          as: :select,
          collection: Current.acp.languages.map { |l| [t("languages.#{l}"), l] },
          prompt: true
      end
    end
    f.inputs do
      f.input :notifications,
        as: :check_boxes,
        collection: Admin::NOTIFICATIONS.map { |n| [t("admin.notifications.#{n}"), n] }
    end
    if current_admin.superadmin?
      f.inputs do
        f.input :rights, collection: Admin::RIGHTS, prompt: true
      end
    end
    f.actions
  end

  permit_params do
    pp = %i[name email language]
    pp << :rights if current_admin.superadmin?
    pp << { notifications: [] }
    pp
  end

  config.filters = false
end
