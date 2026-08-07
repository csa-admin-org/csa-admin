# frozen_string_literal: true

class Members::NewsletterFeedsController < Members::BaseController
  include ActiveStorageUrlOptions

  skip_before_action :authenticate_member!
  skip_before_action :set_locale

  def index
    @template = Newsletter::Template.where(feed_enabled: true).find(params[:template_id])
    @locale = Newsletter::Publication.resolve_locale(params[:locale])
    @publications = Newsletter::Publication.for_feed(@template).to_a

    if stale?(etag: [ @template, @locale, *@publications ], last_modified: feed_last_modified, public: true)
      I18n.with_locale(@locale) do
        respond_to do |format|
          format.atom
        end
      end
    end
  end

  private

  # Include withdrawn publications so Last-Modified never moves backwards on
  # withdraw (If-Modified-Since-only clients would otherwise get a false 304).
  def feed_last_modified
    [
      Newsletter::Publication.where(newsletter_template_id: @template.id).maximum(:updated_at),
      @template.updated_at
    ].compact.max
  end
end
