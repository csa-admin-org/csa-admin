# frozen_string_literal: true

ActiveAdmin.register_page "Updates" do
  menu false

  content title: proc { t("active_admin.site_footer.updates") } do
    para t(".updates_explanation_html"), class: "description is-loose"
    div class: "content-page" do
      Update.all.first(10).each_with_index do |update, i|
        div class: "update", id: update.name do
          label l(update.date), class: "update-date#{ " is-unread" if unread_count > i }"
          div class: "markdown" do
            update.body(binding)
          end
        end
      end
    end
  end

  controller do
    before_action :set_unread_count
    before_action :mark_as_read
    helper_method :unread_count

    private

    def unread_count
      @unread_count
    end

    def set_unread_count
      @unread_count ||= Update.unread_count(current_admin)
    end

    def mark_as_read
      Update.mark_as_read!(current_admin)
    end
  end
end
