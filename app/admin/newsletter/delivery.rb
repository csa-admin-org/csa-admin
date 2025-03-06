# frozen_string_literal: true

ActiveAdmin.register Newsletter::Delivery do
  menu false
  actions :index, :show

  filter :newsletter
  filter :member,
    as: :select,
    collection: -> { Member.joins(:newsletter_deliveries).order_by_name.distinct }
  filter :with_email, as: :string

  breadcrumb do
    links = [ link_to(Newsletter.model_name.human(count: 2), newsletters_path(scope: :all)) ]
    case params[:action]
    when "index"
      if newsletter = Newsletter.find_by(id: params.dig(:q, :newsletter_id_eq))
        links << auto_link(newsletter)
      end
    when "show"
      links << auto_link(resource.newsletter)
      links << link_to(
          Newsletter::Delivery.model_name.human(count: 2),
          newsletter_deliveries_path(q: { newsletter_id_eq: resource.newsletter_id }, scope: :all))
    end
    links
  end

  scope :all
  scope :delivered
  scope :bounced
  scope :ignored

  includes :newsletter, :member
  index download_links: false do
    if params.dig(:q, :newsletter_id_eq).present?
      column :member
    else
      column :newsletter
    end
    column :email, ->(d) { d.email }
    column :date, ->(d) {
      timestamp = d.delivered_at || d.bounced_at || d.processed_at || d.created_at
      l(timestamp, format: :medium)
    }
    column :state, ->(d) { status_tag(d.state) }, class: "text-right"
    actions
  end

  show do |delivery|
    columns do
      column "data-controller" => "iframe" do
        panel t(".preview") do
          div class: "iframe-wrapper" do
            iframe(
              srcdoc: delivery.mail_preview,
              scrolling: "no",
              class: "mail_preview",
              "data-iframe-target" => "iframe")
          end
        end
      end
      column do
        panel t(".details") do
          attributes_table do
            case delivery.state
            when "delivered"
              row(:delivered_at) { l(delivery.delivered_at, format: :medium) }
            when "bounced"
              row(:bounced_at) { l(delivery.bounced_at, format: :medium) }
              row(:bounce_type)
              row(:bounce_description)
            when "ignored"
              row(:processed_at) { l(delivery.processed_at, format: :medium) }
              row(:email_suppression_reasons) {
                content_tag :div do
                  if delivery.email?
                    delivery.email_suppression_reasons.map { |r| status_tag(r.underscore) }
                  else
                    status_tag(:no_email)
                  end
                end
              }
            end
            row(:member) { auto_link(delivery.member) }
            row(:audience) { delivery.newsletter.audience_name }
            row(:from) { delivery.newsletter.from || Current.org.email_default_from }
            row(:attachments) { delivery.newsletter.attachments.map { |a| display_attachment(a.file) } }
          end
        end
      end
    end
  end
end
