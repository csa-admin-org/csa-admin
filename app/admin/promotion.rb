# frozen_string_literal: true

ActiveAdmin.register Promotion do
  menu parent: :other, priority: 6

  includes :promotion_claims

  scope :all
  scope :active, default: true
  scope :archived

  filter :amount, as: :numeric
  filter :uses, as: :numeric, label: -> { Promotion.human_attribute_name(:max_uses) }

  sidebar :info, only: :index do
    side_panel t(".info"), action: handbook_icon_link("promotions") do
      para t(".promotion_info")
    end
  end

  index download_links: false do
    column :name, ->(code) { display_name_with_public_name(code) }, sortable: false
    column Promotion.human_attribute_name(:amount), ->(code) { cur(code.amount) }, class: "text-right"
    column :ends_on, ->(code) { l(code.ends_on, format: :short) if code.ends_on }, class: "text-right"
    column Promotion.human_attribute_name(:max_uses), ->(code) {
      used = code.promotion_claims.occupying.count
      text = [ used, code.max_uses || "∞" ].join("&nbsp;/&nbsp;").html_safe
      link_to text, memberships_with_promotion_path(code)
    }, class: "text-right"
    column :state, ->(code) { promotion_state_tag(code) }, class: "text-right"
    actions
  end

  show do
    url = resource.registration_url(request)

    columns do
      column do
        redemptions = resource.promotion_claims.includes(:member, :membership).order(created_at: :desc)
        panel link_to(PromotionClaim.model_name.human(count: 2), memberships_with_promotion_path(resource)),
          icon: "users",
          count: redemptions.size do
          if redemptions.none?
            div(class: "missing-data") { t("promotions.no_redemptions") }
          else
            table_for redemptions, class: "table-auto" do
              column(Member.model_name.human) { |redemption| auto_link redemption.member }
              column(Membership.model_name.human, class: "text-right") { |redemption|
                auto_link redemption.membership, redemption.membership.id if redemption.membership
              }
              column(PromotionClaim.human_attribute_name(:benefit_amount), class: "text-right tabular-nums") { |redemption|
                cur(redemption.benefit_amount) if redemption.benefit_amount
              }
              column(PromotionClaim.human_attribute_name(:status), class: "text-right") { |redemption|
                promotion_claim_status_tag(redemption)
              }
            end
          end
        end
      end

      column do
        panel t("active_admin.resource.show.details"), icon: "notebook-text" do
          attributes_table do
            row(:name) { display_name_with_public_name(resource) }
            row(:state) { promotion_state_tag(resource) }
            row :ends_on
          end
        end

        panel Promotion.human_attribute_name(:amount), icon: "ticket-percent" do
          attributes_table do
            row(:amount) { cur(resource.amount) }
            row(:max_uses) {
              mode = resource.max_uses_mode
              content_tag(:span, t("promotions.uses.#{mode}"), class: "status-tag", data: { status: mode })
            }
            row :commitment_required if Current.org.trial_baskets?
          end
        end

        panel t("promotions.registration_url"), icon: "link" do
          div class: "registration-share",
            "data-controller" => "clipboard",
            "data-clipboard-text-value" => url,
            "data-clipboard-copy-label-value" => t("promotions.copy"),
            "data-clipboard-copied-label-value" => t("promotions.copied") do
            div class: "registration-url" do
              span url, class: "registration-url-text"
              button type: "button",
                class: "registration-url-copy",
                title: t("promotions.copy"),
                aria: { label: t("promotions.copy") },
                "data-clipboard-target" => "button",
                "data-action" => "clipboard#copy" do
                text_node icon("copy", class: "icon-4 registration-url-copy-icon")
                text_node icon("check", class: "icon-4 registration-url-copied-icon")
              end
            end
            image = QRCode.new(url).image
            text_node image_tag(
              "data:image/png;base64,#{Base64.strict_encode64(image.read)}",
              alt: resource.public_name,
              class: "registration-qr",
              width: 96,
              height: 96)
          end
        end
      end
    end
  end

  form do |f|
    f.inputs t(".details"), icon: "notebook-text" do
      render partial: "public_name", locals: {
        f: f,
        resource: resource,
        context: self,
        public_name_hint: t("formtastic.hints.promotion.public_name")
      }
      f.input :ends_on, as: :date_picker, hint: t("formtastic.hints.promotion.ends_on"), input_html: { min: Date.current }
    end
    f.inputs Promotion.human_attribute_name(:amount), icon: "ticket-percent" do
      f.input :amount, as: :number, step: 0.01, min: 0.01, required: true,
        label: t("promotions.amount_with_currency", currency: currency_symbol)
      f.input :max_uses_mode, as: :radio,
        label: t("promotions.uses.count"),
        collection: %w[unlimited unique].map { |mode| [ t("promotions.uses.#{mode}"), mode ] },
        hint: t("formtastic.hints.promotion.max_uses")
      if Current.org.trial_baskets?
        f.input :commitment_required, hint: t("formtastic.hints.promotion.commitment_required")
      end
    end
    f.actions
  end

  action_item :archive, only: :show, if: -> { !resource.archived? && authorized?(:archive, resource) } do
    action_button t("active_admin.shared.action_items.archive"), archive_promotion_path(resource),
      data: { confirm: t("active_admin.shared.action_items.archive_confirm") },
      class: "destructive",
      icon: "archive"
  end

  action_item :unarchive, only: :show, if: -> { resource.archived? && authorized?(:unarchive, resource) } do
    action_button t("active_admin.shared.action_items.unarchive"), unarchive_promotion_path(resource),
      icon: "archive-restore"
  end

  member_action :archive, method: :post do
    resource.archive!
    redirect_to resource_path
  end

  member_action :unarchive, method: :post do
    resource.unarchive!
    redirect_to resource_path
  end

  permit_params :ends_on, :max_uses_mode, :amount, :commitment_required,
    *Organization.languages.flat_map { |locale|
      [ "public_name_#{locale}", "admin_name_#{locale}" ]
    }

  controller do
    def scoped_collection
      super.kept
    end
  end
end
