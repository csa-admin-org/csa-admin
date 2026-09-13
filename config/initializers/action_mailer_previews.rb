# frozen_string_literal: true

# MailTemplate / Newsletter::Template constantize a preview class for in-app
# mail preview. Rails then skips the rest of Preview.all (it only loads files
# when descendants is empty), so /rails/mailers would show a single mailer.
module ActionMailerPreviewLoadAll
  def all
    load_previews
    descendants.sort_by { |mailer| mailer.name.titleize }
  end
end

ActionMailer::Preview.singleton_class.prepend(ActionMailerPreviewLoadAll)
