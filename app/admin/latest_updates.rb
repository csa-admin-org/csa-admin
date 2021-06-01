ActiveAdmin.register_page 'LatestUpdates' do
  menu false

  content title: ->(_) { I18n.t('layouts.footer.latest_updates').capitalize } do
    para t('.latest_updates_explanation_html'), class: 'notice'
    columns do
      column do
        Update.all.each_with_index do |update, i|
          panel l(update.date), class: unread_count > i ? 'unread' : '' do
            update.content
          end
        end
      end
    end
  end

  controller do
    before_action :set_unread_count
    before_action :set_latest_update_read
    helper_method :unread_count

    private

    def unread_count
      @unread_count
    end

    def set_unread_count
      @unread_count ||= Update.unread_count(current_admin)
    end

    def set_latest_update_read
      Update.mark_as_read!(current_admin)
    end
  end
end
