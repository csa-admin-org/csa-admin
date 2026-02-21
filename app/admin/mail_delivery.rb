# frozen_string_literal: true

ActiveAdmin.register MailDelivery do
  menu false
  actions :index, :show

  breadcrumb do
    links = []
    source = params[:action] == "show" ? resource.source : source_record

    case source
    when Newsletter
      links << link_to(Newsletter.model_name.human(count: 2), newsletters_path(scope: :all))
      links << auto_link(source)
    when MailTemplate
      links << link_to(MailTemplate.model_name.human(count: 2), mail_templates_path(scope: :all))
      links << link_to(source.scope_label, mail_templates_path(scope: source.scope_name))
      links << auto_link(source)
    when Member
      links << link_to(Member.model_name.human(count: 2), members_path(scope: :all))
      links << auto_link(source)
    end

    if params[:action] == "show"
      deliveries_params = resource.newsletter? ? { newsletter_id: source.id } : { mail_template_id: source.id }
      links << link_to(MailDelivery.model_name.human(count: 2), mail_deliveries_path(**deliveries_params))
    end

    links
  end

  filter :with_subject,
    as: :string,
    label: -> { MailDelivery.human_attribute_name(:subject) },
    if: proc { source_type == :member }
  filter :member,
    as: :select,
    if: proc { source_type != :member },
    collection: -> { members_collection(collection) }
  filter :member_name_cont,
    label: -> { Member.human_attribute_name(:name) },
    if: proc { source_type != :member }
  filter :with_email,
    as: :string,
    label: -> { MailDelivery::Email.human_attribute_name(:email) },
    if: proc { source_type != :newsletter || !source_record.draft? }

  scope :all,
    default: true,
    if: proc { source_type != :newsletter || !source_record.draft? }
  scope :newsletters, group: :source, if: proc { source_type == :member }
  scope :mail_templates, group: :source, if: proc { source_type == :member }
  MailDelivery::Email::STATES.each do |email_state|
    scope email_state.to_sym,
      group: :email,
      if: proc {
        source_type.in?(%i[newsletter mail_template]) &&
          (source_type != :newsletter || !source_record.draft?)
      }
  end

  includes :member, :emails

  index download_links: false do
    column :id
    if source_type == :member
      column :subject, ->(d) { auto_link d, d.subject || d.source.display_name }, sortable: false
    end
    column :member, sortable: "members.name" if source_type != :member
    column :created_at, ->(d) { l(d.created_at, format: :short) }, sortable: true
    column :state, ->(d) { status_tag(d.state) }, class: "text-right"
    actions class: "hidden"
  end

  show do |delivery|
    columns do
      column "data-controller" => "iframe" do
        if delivery.processing?
          panel t(".preview"), data: { controller: "auto-refresh" } do
            div class: "flex min-h-96 items-center justify-center" do
              render "shared/spinner"
            end
          end
        else
          panel t(".preview") do
            div class: "iframe-wrapper" do
              preview = if delivery.draft? && delivery.newsletter?
                delivery.source.mail_preview(delivery.member.language)
              else
                delivery.mail_preview
              end
              iframe(
                srcdoc: preview,
                scrolling: "no",
                class: "mail_preview",
                "data-iframe-target" => "iframe")
            end
          end
        end
      end
      column do
        panel t(".details") do
          attributes_table do
            row(:id)
            row(:member) { auto_link(delivery.member) }
            row(:created_at) { l(delivery.created_at, format: :short) }
          end
        end
        if delivery.newsletter?
          nl = delivery.source
          panel link_to(Newsletter.model_name.human, nl), action: handbook_icon_link("newsletters", anchor: "subscribe") do
            attributes_table do
              row(:from) { nl.from || Current.org.email_default_from }
              row(:audience) { nl.audience_name }
              row(:attachments) { nl.attachments.map { |a| display_attachment(a.file) } }
            end
          end
        else
          mt = delivery.source
          panel link_to(MailTemplate.model_name.human, mt) do
            div class: "mx-2 mb-2" do
              para mt.description, class: "text-base description"
            end
          end
        end
        panel t(".recipients") do
          if delivery.draft?
            member_emails = delivery.member.emails_array
            if member_emails.empty?
              div(class: "missing-data") { t("active_admin.status_tag.no_email") }
            else
              div(class: "grid gap-y-2") do
                member_emails.each do |email_address|
                  suppressions = EmailSuppression.active.where(email: email_address)
                  suppressed = suppressions.any?
                  div do
                    div(class: "flex flex-wrap items-center justify-start mx-2 gap-2") do
                      h4 email_address, class: "m-0 text-lg font-extralight"
                      status_tag(suppressed ? :suppressed : :active, class: "m-0")
                    end
                    if suppressed
                      attributes_table do
                        row(MailDelivery::Email.human_attribute_name(:email_suppression_reasons)) {
                          suppressions.map(&:reason).uniq.map { |r|
                            capture { status_tag(r.underscore) }
                          }.join(" ").html_safe
                        }
                      end
                    end
                  end
                end
              end
            end
          elsif delivery.emails.none?
            div(class: "missing-data") { t("active_admin.status_tag.no_email") }
          else
            div(class: "grid gap-y-6") do
              delivery.emails.order(:created_at).each do |email|
                div do
                  div(class: "flex flex-wrap items-center justify-start mx-2 mb-1 gap-2") do
                    h4 email.email, class: "m-0 text-lg font-extralight"
                    status_tag(email.state, class: "m-0")
                  end
                  attributes_table_for email do
                    case email.state
                    when "bounced"
                      row(:bounced_at) { l(email.bounced_at, format: :short) }
                      row(:bounce_type) { status_tag(email.bounce_type.underscore) }
                      row(:bounce_description) { email.bounce_description }
                    when "delivered"
                      row(:delivered_at) { l(email.delivered_at, format: :short) }
                    when "suppressed"
                      row(:suppressed_at) { l(email.created_at, format: :short) }
                      row(:email_suppression_reasons) {
                        email.email_suppression_reasons.map { |r|
                          capture { status_tag(r.underscore) }
                        }.join(" ").html_safe
                      }
                    else
                      row(:created_at) { l(email.created_at, format: :short) }
                    end
                  end
                end
              end
            end
          end
        end

        if delivery.show_missing_emails?
          panel t(".missing_deliveries") do
            div(class: "grid gap-y-2") do
              delivery.missing_emails.each do |email|
                div(class: "flex flex-wrap items-center justify-start mx-2 gap-2") do
                  h4(class: "m-0 text-lg font-extralight") { email }
                  if authorized?(:deliver_missing_email, resource)
                    div do
                      panel_button t(".send_email"), deliver_missing_email_mail_delivery_path(resource),
                        params: { email: email },
                        form: { class: "inline" },
                        data: { confirm: t(".confirm") }
                    end
                  end
                end
              end
            end
            div class: "mt-6 px-2" do
              para t(".missing_deliveries_description"), class: "italic text-sm text-gray-400 dark:text-gray-600"
            end
          end
        end
      end
    end
  end

  member_action :deliver_missing_email, method: :post do
    resource.deliver_missing_email!(params.require(:email))
    redirect_to resource_path, notice: t("active_admin.resources.mail_delivery.flash.notice")
  end

  controller do
    helper_method :source_type, :source_record

    def source_type
      @source_type ||= if params[:newsletter_id] then :newsletter
      elsif params[:mail_template_id] then :mail_template
      elsif params[:member_id] then :member
      end
    end

    def source_record
      @source_record ||= case source_type
      when :newsletter then Newsletter.find(params[:newsletter_id])
      when :mail_template then MailTemplate.find(params[:mail_template_id])
      when :member then Member.find(params[:member_id])
      end
    end

    def scoped_collection
      scope = end_of_association_chain
      case source_type
      when :newsletter then scope.newsletter_id_eq(source_record.id)
      when :mail_template then scope.mail_template_id_eq(source_record.id)
      when :member then scope.where(member: source_record)
      else scope
      end
    end

    def apply_sorting(chain)
      super(chain).left_joins(:member).merge(Member.order_by_name)
    end

    def find_collection(*)
      collection = super
      preload_sources(collection)
      collection
    end

    private

    def preload_sources(collection)
      records = collection.to_a

      # Preload newsletters (batch query from mailable_ids)
      if source_type != :mail_template
        nl_deliveries = records.select(&:newsletter?)
        if nl_deliveries.any?
          newsletter_ids = nl_deliveries.flat_map(&:mailable_ids).uniq
          newsletters = Newsletter.where(id: newsletter_ids).index_by(&:id)
          nl_deliveries.each { |d| d.preload_source!(newsletters[d.mailable_ids.first]) }
        end
      end

      # Preload mail templates (tiny table, one query loads all)
      if source_type != :newsletter
        tpl_deliveries = records.reject(&:newsletter?)
        if tpl_deliveries.any?
          templates = MailTemplate.all.index_by(&:title)
          tpl_deliveries.each { |d| d.preload_source!(templates[d.mail_template_title]) }
        end
      end
    end
  end

  order_by("members.name") do |clause|
    Member
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.sort_order = "created_at_desc"
  config.per_page = 50
end
