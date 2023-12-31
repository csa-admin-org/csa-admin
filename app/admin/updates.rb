ActiveAdmin.register_page "Updates" do
  menu false

  content title: proc { t("layouts.footer.updates") } do
    columns do
      column do
        div class: "content" do
          para t(".updates_explanation_html"), class: "notice"
        end
        Update.all.first(20).each_with_index do |update, i|
          panel l(update.date), class: unread_count > i ? "unread" : "", id: update.name do
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
