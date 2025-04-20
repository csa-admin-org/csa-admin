# frozen_string_literal: true

ActiveAdmin.register Newsletter::Delivery do
  menu false
  actions :index, :show

  filter :newsletter,
    as: :select,
    collection: -> { Newsletter.order(id: :desc).distinct }
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
  scope :draft
  scope :delivered
  scope :bounced
  scope :ignored

  includes :newsletter, :member
  index download_links: false do
    if params.dig(:q, :newsletter_id_eq).present?
      column :member, sortable: "members.name"
    else
      column :newsletter, sortable: "newsletters.subject"
    end
    column :email, ->(d) { auto_link d, d.email }
    column :date, ->(d) {
      timestamp = d.delivered_at || d.bounced_at || d.processed_at || d.created_at
      auto_link d, l(timestamp, format: :medium)
    }, sortable: "date"
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
            when "draft"
              row(:created_at) { l(delivery.created_at, format: :medium) }
            when "delivered"
              row(:delivered_at) { l(delivery.delivered_at, format: :medium) }
            when "bounced"
              row(:bounced_at) { l(delivery.bounced_at, format: :medium) }
              row(:bounce_type)
              row(:bounce_description)
            when "ignored"
              if delivery.processed?
                row(:processed_at) { l(delivery.processed_at, format: :medium) }
              else
                row(:created_at) { l(delivery.created_at, format: :medium) }
              end
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
            row(:newsletter) { auto_link(delivery.newsletter) }
            row(:member) { auto_link(delivery.member) }
            row(:email) { mail_to(delivery.email) }
            row(:audience) { delivery.newsletter.audience_name }
            row(:from) { delivery.newsletter.from || Current.org.email_default_from }
            row(:attachments) { delivery.newsletter.attachments.map { |a| display_attachment(a.file) } }
          end
        end
      end
    end
  end

  controller do
    def apply_sorting(chain)
      super(chain).joins(:member, :newsletter).merge(Member.order_by_name)
    end
  end

  order_by("members.name") do |clause|
    Member
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  order_by("newsletters.subject") do |clause|
    Newsletter
      .reorder_by_subject(clause.order)
      .order_values
      .join(" ")
  end

  order_by("date") do |clause|
    %i[
      delivered_at
      bounced_at
      processed_at
      created_at
    ].map { |attr| "newsletter_deliveries.#{attr} #{clause.order}" }.join(", ")
  end

  config.sort_order = "date_desc"
  config.per_page = 100
end
