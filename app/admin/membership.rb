# frozen_string_literal: true

ActiveAdmin.register Membership do
  menu priority: 3

  breadcrumb do
    if params[:action] == "new"
      [ link_to(Membership.model_name.human(count: 2), memberships_path) ]
    elsif params["action"] != "index"
      links = [
        link_to(Member.model_name.human(count: 2), members_path),
        auto_link(resource.member),
        link_to(
          Membership.model_name.human(count: 2),
          memberships_path(q: { member_id_eq: resource.member_id }, scope: :all))
      ]
      if params["action"].in? %W[edit]
        links << auto_link(resource)
      end
      links
    end
  end

  scope :all
  scope :trial, if: -> { Current.acp.trial_basket_count.positive? }
  scope :ongoing, default: true
  scope :future
  scope :past

  filter :id
  filter :member,
    as: :select,
    collection: -> { Member.joins(:memberships).order(:name).distinct }
  filter :basket_size,
    as: :select,
    collection: -> { admin_basket_sizes_collection }
  filter :with_memberships_basket_complement,
    as: :select,
    collection: -> { admin_basket_complements_collection },
    label: proc { BasketComplement.model_name.human },
    if: :any_basket_complements?
  filter :depot, as: :select, collection: -> { admin_depots_collection }
  filter :delivery_cycle,
    as: :select,
    collection: -> { admin_delivery_cycles_collection }
  filter :renewal_state,
    as: :select,
    collection: -> { renewal_states_collection }
  filter :started_on
  filter :ended_on
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :billing_year_division,
    as: :select,
    collection: -> {
      divisions = Membership.pluck(:billing_year_division).uniq.sort
      divisions.map { |i| [ t("billing.year_division.x#{i}"), i ] }
    }
  filter :basket_price_extra,
    label: proc { Current.acp.basket_price_extra_title },
    if: proc { Current.acp.feature?("basket_price_extra") }
  filter :activity_participations_accepted,
    label: proc { t_activity("active_admin.resource.index.activity_participations_accepted") },
    if: proc { Current.acp.feature?("activity") }
  filter :activity_participations_demanded,
    label: proc { t_activity("active_admin.resource.index.activity_participations_demanded") },
    if: proc { Current.acp.feature?("activity") }

  includes :member, :baskets, :delivery_cycle
  index do
    column :id, ->(m) { auto_link m, m.id }
    column :member, sortable: "members.name"
    column :started_on, ->(m) { auto_link m, l(m.started_on, format: :number_short) }, class: "text-right"
    column :ended_on, ->(m) { auto_link m, l(m.ended_on, format: :number_short) }, class: "text-right"
    if Current.acp.feature?("activity")
      column activities_human_name, ->(m) {
        link_to(
          "#{m.activity_participations_accepted} / #{m.activity_participations_demanded}",
          activity_participations_path(q: {
            member_id_eq: m.member_id,
            during_year: m.fiscal_year
          }, scope: "all"))
      }, sortable: "activity_participations_demanded", class: "text-right"
    end
    column :baskets_count,
      ->(m) { auto_link m, "#{m.past_baskets_count} / #{m.baskets_count}" },
      class: "text-right"
    actions
  end

  sidebar :renewal, only: :index do
    side_panel t(".renewal"), action: handbook_icon_link("membership_renewal") do
      renewal = MembershipsRenewal.new
      if !Delivery.any_next_year?
        t(".no_next_year_deliveries",
          fiscal_year: renewal.next_fy,
          new_delivery_path: new_delivery_path).html_safe
      else
        ul do
          li do
            openable_count = renewal.openable.count
            t(".openable_renewals",
              count: openable_count,
              count_link: link_to(
                openable_count,
                collection_path(scope: :all, q: { renewal_state_eq: :renewal_pending, during_year: Current.acp.current_fiscal_year.year }))
            ).html_safe
          end
          if MailTemplate.active_template(:membership_renewal)
            li do
              renewal_opened_count = renewal.opened.count
              t(".opened_renewals",
                count: renewal_opened_count,
                count_link: link_to(
                  renewal_opened_count,
                  collection_path(scope: :all, q: { renewal_state_eq: :renewal_opened, during_year: Current.acp.current_fiscal_year.year }))
              ).html_safe
            end
          end
          li do
            renewed_count = renewal.renewed.count
            t(".renewed_renewals",
              count: renewed_count,
              count_link: link_to(
                renewed_count,
                collection_path(scope: :all, q: { renewal_state_eq: :renewed, during_year: Current.acp.current_fiscal_year.year }))
            ).html_safe
          end
          li do
            end_of_year = Current.acp.current_fiscal_year.end_of_year
            renewal_canceled_count = Membership.where(renew: false).where(ended_on: end_of_year).count
            t(".canceled_renewals",
              count: renewal_canceled_count,
              count_link: link_to(
                renewal_canceled_count,
                collection_path(scope: :all, q: { renewal_state_eq: :renewal_canceled, during_year: Current.acp.current_fiscal_year.year, ended_on_gteq: end_of_year, ended_on_lteq: end_of_year }))
            ).html_safe
          end
        end
        renewable_count = renewal.renewable.count
        if renewable_count.positive?
          if renewal.renewing?
            div class: "mt-3 flex justify-center items-center italic" do
              icon("arrow-path", class: "h-4 w-4 mr-2") + t(".renewing")
            end
          elsif renewal.opening?
            div class: "mt-3 flex justify-center items-center italic" do
              icon("paper-airplane", class: "h-4 w-4 mr-2") + t(".opening")
            end
          else
            div class: "mt-2" do
              if authorized?(:open_renewal_all, Membership) && MailTemplate.active_template(:membership_renewal)
                openable_count = renewal.openable.count
                if openable_count.positive?
                  div class: "mt-2" do
                    button_to open_renewal_all_memberships_path,
                      form: { class: "flex justify-center", data: { controller: "disable", disable_with_value: t(".opening") } },
                      class: "action-item-button secondary small", data: { confirm: t("active_admin.batch_actions.default_confirmation") } do
                        icon("paper-airplane", class: "h-4 w-4 mr-2") + t(".open_renewal_all_action", count: openable_count)
                      end
                  end
                end
              end
              if authorized?(:renew_all, Membership)
                div class: "mt-2" do
                  button_to renew_all_memberships_path,
                    form: { class: "flex justify-center", data: { controller: "disable", disable_with_value: t(".renewing") } },
                    class: "action-item-button secondary small", data: { confirm: t("active_admin.batch_actions.default_confirmation") } do
                      icon("arrow-path", class: "h-4 w-4 mr-2") + t(".renew_all_action", count: renewable_count)
                    end
                end
              end
            end
          end
        end
      end
    end
  end

  sidebar :basket_price_extra_title, only: :index, if: -> { Current.acp.feature?("basket_price_extra") && params.dig(:q, :during_year).present? } do
    side_panel Current.acp.basket_price_extra_title, action: handbook_icon_link("basket_price_extra") do
      coll =
        collection
          .unscope(:includes, :joins, :order)
          .offset(nil).limit(nil)
          .joins(:member)
          .merge(Member.no_salary_basket)
      baskets = Basket.billable.where(membership: coll)
      if coll.where("basket_price_extra < 0").any?
        div class: "flex justify-end" do
          sum = baskets.where("price_extra > 0").sum("quantity * price_extra")
          span cur(sum)
        end
        div class: "flex justify-end" do
          sum = baskets.where("price_extra < 0").sum("quantity * price_extra")
          span cur(sum)
        end
      end
      div class: "flex justify-between" do
        sum = baskets.sum("quantity * price_extra")
        span t("active_admin.shared.sidebar_section.amount")
        span cur(sum), class: "font-bold"
      end
    end
  end

  collection_action :renew_all, method: :post do
    authorize!(:renew_all, Membership)
    MembershipsRenewal.new.renew_all!
    redirect_to collection_path, notice: t("active_admin.flash.renew_notice")
  rescue MembershipsRenewal::MissingDeliveriesError
    redirect_to collection_path,
      alert: t("active_admin.flash.renew_missing_deliveries_alert", next_year: MembershipsRenewal.new.next_fy)
  end

  collection_action :open_renewal_all, method: :post do
    authorize!(:open_renewal_all, Membership)
    MembershipsRenewal.new.open_all!
    redirect_to collection_path, notice: t("active_admin.flash.open_renewals_notice")
  rescue MembershipsRenewal::MissingDeliveriesError
    redirect_to collection_path,
      alert: t("active_admin.flash.renew_missing_deliveries_alert", next_year: MembershipsRenewal.new.next_fy)
  end

  csv do
    column(:id)
    column(:member_id)
    column(:name) { |m| m.member.name }
    column(:emails) { |m| m.member.emails_array.join(", ") }
    column(:phones) { |m| m.member.phones_array.map { |p| display_phone(p) }.join(", ") }
    column(:note) { |m| m.member.note }
    column(:started_on)
    column(:ended_on)
    column(:baskets_count)
    if Current.acp.trial_basket_count.positive?
      column(:baskets_trial_count) { |m| m.baskets.count(&:trial?) }
    end
    if feature?("absence")
      column(:absences_included)
      column(:baskets_absent_count) { |m| m.baskets.count(&:absent?) }
    end
    column(:basket_size) { |m| basket_size_description(m, text_only: true, public_name: false) }
    column(:basket_price) { |m| cur(m.basket_price) }
    if Current.acp.feature?("basket_price_extra")
      column(Current.acp.basket_price_extra_title) { |m|
        if Current.acp.basket_price_extra_dynamic_pricing?
          m.basket_price_extra
        else
          cur(m.basket_price_extra)
        end
      }
      column("#{Current.acp.basket_price_extra_title} - #{Membership.human_attribute_name(:total)}") { |m| cur(m.baskets_price_extra) }
    end
    column(:basket_quantity)
    if BasketComplement.kept.any?
      column(:basket_complements) { |m|
        basket_complements_description(m.memberships_basket_complements.includes(:basket_complement),
          text_only: true,
          public_name: false)
      }
    end
    column(:depot) { |m| m.depot.name }
    column(:depot_price) { |m| cur(m.depot_price) }
    column(:delivery_cycle) { |m| m.delivery_cycle.name }
    if Current.acp.feature?("activity")
      column(activity_scoped_attribute(:activity_participations_demanded), &:activity_participations_demanded)
      column(activity_scoped_attribute(:activity_participations_accepted), &:activity_participations_accepted)
      column(activity_scoped_attribute(:missing_activity_participations), &:missing_activity_participations)
    end
    column(:renewal_state) { |m| t("active_admin.status_tag.#{m.renewal_state}") }
    column(:renewed_at)
    column(:renewal_note)
    column(activity_scoped_attribute(:activity_participations_annual_price_change)) { |m| cur(m.activity_participations_annual_price_change) }
    column(:billing_year_division) { |m| t("billing.year_division.x#{m.billing_year_division}") }
    column(:baskets_annual_price_change) { |m| cur(m.baskets_annual_price_change) }
    if BasketComplement.kept.any?
      column(:basket_complements_annual_price_change) { |m| cur(m.basket_complements_annual_price_change) }
    end
    column(:price) { |m| cur(m.price) }
    column(:invoices_amount) { |m| cur(m.invoices_amount) }
    column(:missing_invoices_amount) { |m| cur(m.missing_invoices_amount) }
  end

  show do |m|
    columns do
      column do
        next_basket = m.next_basket
        panel Basket.model_name.human(count: 2), count: m.baskets_count do
          table_for(m.baskets.preload(
            :membership,
            :delivery,
            :basket_size,
            :depot,
            :complements,
            :absence,
            baskets_basket_complements: :basket_complement
          ),
            row_class: ->(b) {
              classes = []
              classes << "bg-gray-200 dark:bg-gray-700" if b == next_basket
              classes << "disabled" if b.absent?
              classes << "line-through" unless b.billable?
              classes.join(" ")
            },
            class: "table-auto"
          ) do
            column(:delivery, class: "md:w-32") { |b| link_to b.delivery.display_name(format: :number_short), b.delivery }
            column(:description)
            column(:depot)
            if m.baskets.where(state: [ :absent, :trial ]).any?
              column(class: "text-right") { |b| display_basket_state(b) }
            end
            column(nil) { |b|
              if authorized?(:update, b)
                div class: "data-table-resource-actions" do
                  link_to edit_basket_path(b), title: t(".edit") do
                    icon "pencil-square", class: "h-5 w-5"
                  end
                end
              end
            }
          end
        end
        if feature?("absence") && m.baskets.provisionally_absent.any?
          div class: "footnote" do
            content_tag(:span, "*") + t(".provisional_absences")
          end
        end
      end

      column do
        panel t(".details") do
          attributes_table do
            row :id
            row :member
            row(:period) { [ l(m.started_on), l(m.ended_on) ].join(" - ") }
            row(:fiscal_year)
            row(:created_at) { l m.created_at, format: :long }
          end
        end

        panel t(".config") do
          attributes_table do
            row(:basket_size) { basket_size_description(m, text_only: true, public_name: false) }
            if BasketComplement.kept.any?
              row(:memberships_basket_complements) {
                basket_complements_description(
                  m.memberships_basket_complements.includes(:basket_complement), text_only: true, public_name: false)
                }
            end
            row :depot
            row(:delivery_cycle) {
              cycle = m.delivery_cycle
              auto_link cycle, "#{cycle.display_name} (#{cycle.deliveries_count_for(m.fy_year)})"
            }
            if feature?("absence") && m.absences_included_annually.positive?
              row(:absences_included) {
                used = m.baskets.definitely_absent.count
                link_to absences_path(q: { member_id_eq: m.member_id, during_year: m.fy_year }, scope: :all) do
                  t(".absences_used", used: used, count: m.absences_included)
                end
              }
            end
          end
        end

        if Current.fiscal_year >= m.fiscal_year
          panel Membership.human_attribute_name(:renew), action: handbook_icon_link("membership_renewal") do
            attributes_table do
              row(:status) { status_tag(m.renewal_state) }
              if m.renewed?
                row(:renewed_at) { l m.renewed_at.to_date }
                row(:renewed_membership)
                row :renewal_note
              elsif m.canceled?
                if Current.acp.annual_fee?
                  row(:renewal_annual_fee) {
                    status_tag(!!m.renewal_annual_fee)
                    span { cur(m.renewal_annual_fee) }
                  }
                end
                row :renewal_note
                if m.ended_on == Current.fiscal_year.end_of_year && authorized?(:mark_renewal_as_pending, m)
                  div class: "mt-2 py-1 flex items-center justify-center gap-4" do
                    div do
                      button_to mark_renewal_as_pending_membership_path(m),
                        form: {
                          data: { controller: "disable", disable_with_value: t("formtastic.processing") }
                        },
                        class: "action-item-button small secondary",
                        data: { confirm: t(".confirm") } do
                          icon("arrow-uturn-left", class: "h-4 w-4 mr-2") + t(".mark_renewal_as_pending")
                        end
                    end
                  end
                end
              elsif m.renewal_opened?
                row(:renewal_opened_at) { l m.renewal_opened_at.to_date }
                if Current.acp.open_renewal_reminder_sent_after_in_days?
                  row(:renewal_reminder_sent_at) {
                    if m.renewal_reminder_sent_at
                      l m.renewal_reminder_sent_at.to_date
                    end
                  }
                end
                div class: "mt-2 py-1 flex items-center justify-center gap-4" do
                  if authorized?(:renew, m)
                    button_to renew_membership_path(m),
                      form: {
                        data: { controller: "disable", disable_with_value: t("formtastic.processing") }
                      },
                      data: { confirm: t(".confirm") },
                      class: "action-item-button small secondary",
                      disabled: !m.can_renew? do
                        icon("arrow-path", class: "h-4 w-4 mr-2") + t(".renew")
                      end
                  end
                  if authorized?(:cancel, m)
                    button_to cancel_membership_path(m),
                      form: {
                        data: { controller: "disable", disable_with_value: t("formtastic.processing") }
                      },
                      data: { confirm: t(".confirm") },
                      class: "action-item-button small secondary" do
                        icon("x-circle", class: "h-4 w-4 mr-2") + t(".cancel_renewal")
                      end
                  end
                end
              else
                div class: "mt-2 py-1 flex items-center justify-center gap-4" do
                  if Delivery.any_next_year?
                    if authorized?(:open_renewal, m) && MailTemplate.active_template(:membership_renewal)
                      div do
                        button_to open_renewal_membership_path(m),
                          form: {
                            data: { controller: "disable", disable_with_value: t("formtastic.processing") }
                          },
                          data: { confirm: t(".confirm") },
                          class: "action-item-button small secondary" do
                            icon("paper-airplane", class: "h-4 w-4 mr-2") + t(".open_renewal")
                          end
                      end
                    end
                    if authorized?(:renew, m)
                      div do
                        button_to renew_membership_path(m),
                          form: {
                            data: { controller: "disable", disable_with_value: t("formtastic.processing") }
                          },
                          data: { confirm: t(".confirm") },
                          class: "action-item-button small secondary",
                          disabled: !m.can_renew? do
                            icon("arrow-path", class: "h-4 w-4 mr-2") + t(".renew")
                          end
                      end
                    end
                  end
                  if authorized?(:cancel, m)
                    div do
                      button_to cancel_membership_path(m),
                        form: {
                          data: { controller: "disable", disable_with_value: t("formtastic.processing") }
                        },
                        data: { confirm: t(".confirm") },
                        class: "action-item-button small secondary" do
                          icon("x-circle", class: "h-4 w-4 mr-2") + t(".cancel_renewal")
                        end
                    end
                  end
                end
              end
            end
          end
        end

        panel Membership.human_attribute_name(:amount) do
          if m.member.salary_basket?
            div(class: "missing-data") { t(".salary_basket") }
          elsif m.baskets_count.zero?
            div(class: "missing-data") { t(".no_baskets") }
          else
            attributes_table do
              if m.basket_sizes_price.nonzero?
                row(Basket.model_name.human(count: m.baskets_count), class: "text-right") {
                  display_price_description(m.basket_sizes_price, basket_sizes_price_info(m, m.baskets))
                }
              end
              if m.baskets_annual_price_change.nonzero?
                row(t(".baskets_annual_price_change"), class: "text-right") {
                  cur(m.baskets_annual_price_change, unit: false)
                }
              end
              if m.basket_complements.any? && m.basket_complements_price.nonzero?
                row(BasketComplement.model_name.human(count: m.basket_complements.count), class: "text-right") {
                  display_price_description(
                    m.basket_complements_price,
                    membership_basket_complements_price_info(m))
                }
                if m.basket_complements_annual_price_change.nonzero?
                  row(t(".basket_complements_annual_price_change")) {
                    cur(m.basket_complements_annual_price_change, unit: false)
                  }
                end
              end
              if Current.acp.feature?("basket_price_extra") && m.basket_price_extra.nonzero?
                row(:basket_price_extra_title, class: "text-right") {
                  description = baskets_price_extra_info(m, m.baskets, highlight_current: true)
                  display_price_description(m.baskets_price_extra, description)
                }
              end
              if m.depots_price.nonzero?
                row(Depot.model_name.human(count: m.baskets_count), class: "text-right") {
                  display_price_description(m.depots_price, depots_price_info(m.baskets))
                }
              end
              if Current.acp.feature?("activity") && m.activity_participations_annual_price_change.nonzero?
                row(t_activity(".activity_participations_annual_price_change"), class: "text-right") {
                  cur(m.activity_participations_annual_price_change, unit: false)
                }
              end
              row(:price, class: "border-solid border-0 border-t border-gray-800 dark:border-gray-200 text-right font-bold") {
                cur(m.price, format: "%u %n")
              }
            end
          end
        end

        panel t(".billing"), action: handbook_icon_link("billing") do
          attributes_table do
            row(:billing_year_division) { t("billing.year_division.x#{m.billing_year_division}") }
            row(:invoices_amount) {
              link_to(
                cur(m.invoices_amount),
                invoices_path(scope: :all, q: {
                  member_id_eq: resource.member_id,
                  entity_type_in: "Membership",
                  during_year: resource.fiscal_year.year
                }))
            }
            row(:missing_invoices_amount) { cur(m.missing_invoices_amount) }
            if resource.billable?
              row(:next_invoice_on) {
                if Current.acp.recurring_billing?
                  invoicer = Billing::Invoicer.new(resource.member, resource)
                  if invoicer.next_date
                    div class: "flex items-center justify-between gap-2" do
                      span do
                        l(invoicer.next_date, format: :long_medium)
                      end
                      if authorized?(:force_recurring_billing, resource.member) && invoicer.billable?
                        div do
                          button_to t(".invoice_now"), force_recurring_billing_member_path(resource.member),
                            form: {
                              data: { controller: "disable", disable_with_value: t("formtastic.processing") },
                              class: "inline"
                            },
                            data: { confirm: t(".invoice_now_confirm") },
                            class: "action-item-button tiny secondary"
                            end
                      end
                    end
                  end
                else
                  span class: "italic text-gray-400 dark:text-gray-600" do
                    t(".recurring_billing_disabled")
                  end
                end
              }
            end
          end
        end

        if Current.acp.feature?("activity")
          panel activities_human_name, action: handbook_icon_link("activity") do
            ul class: "counts justify-evenly" do
              li class: "w-1/3" do
                counter_tag(
                  Membership.human_attribute_name(:activity_participations_demanded),
                  m.activity_participations_demanded)
              end
              %i[future pending validated rejected].each do |scope|
                li class: "w-1/3" do
                  link_to activity_participations_path(scope: scope, q: { member_id_eq: resource.member_id, during_year: resource.fiscal_year.year }) do
                    counter_tag(
                      Membership.human_attribute_name("activity_participations_#{scope}"),
                      m.member.activity_participations.during_year(m.fiscal_year).send(scope).sum(:participants_count))
                  end
                end
              end
              li class: "w-1/3" do
                link_to invoices_path(scope: :all, q: { entity_type_in: "ActivityParticipation", member_id_eq: resource.member_id, during_year: resource.fiscal_year.year }) do
                  counter_tag(
                    Membership.human_attribute_name(:activity_participations_paid),
                    m.member.invoices.not_canceled.activity_participation_type.during_year(m.fiscal_year).sum(:paid_missing_activity_participations))
                end
              end
            end
          end
        end

        active_admin_comments_for(m)
      end
    end
  end

  form do |f|
    f.inputs t(".details") do
      f.input :member,
        collection: Member.order(:name).map { |d| [ d.name, d.id ] },
        prompt: true
      div class: "single-line" do
        f.input :started_on, as: :date_picker
        f.input :ended_on, as: :date_picker
      end
    end

    if Current.acp.annual_fee? && f.object.canceled?
      f.inputs Membership.human_attribute_name(:renew) do
        f.input :renewal_annual_fee
      end
    end

    if Current.acp.feature?("activity")
      f.inputs activities_human_name, "data-controller" => "form-reset" do
        div class: "panel-actions" do
          handbook_icon_link("activity")
        end

        f.input :activity_participations_demanded_annually,
          label: "#{activities_human_name} (#{t('.full_year')})",
          input_html: {
            data: { "1p_ignore": true, action: "form-reset#reset" }
          },
          hint: t("formtastic.hints.membership.activity_participations_demanded_annually_html")
        f.input :activity_participations_annual_price_change,
          input_html: { data: { form_reset_target: "input" } },
          hint: t("formtastic.hints.membership.activity_participations_annual_price_change_html")
      end
    end

    f.inputs t(".billing") do
      f.input :billing_year_division,
        as: :select,
        collection: billing_year_divisions_collection,
        prompt: true,
        hint: f.object.renewed?
      f.input :baskets_annual_price_change
      if BasketComplement.kept.any?
        f.input :basket_complements_annual_price_change
      end
    end

    h3 t(".config")
    if resource.new_record?
      para t(".membership_configuration_text")
    else
      para t(".membership_configuration_warning_text"), class: "font-bold text-red-600 dark:text-red-400"
      f.inputs do
        f.input :new_config_from, as: :date_picker, required: true
      end
    end
    f.inputs [
      Depot.model_name.human(count: 1),
      DeliveryCycle.model_name.human(count: 1)
    ].to_sentence do
       ol "data-controller" => "form-reset" do
        f.input :depot,
          collection: admin_depots_collection,
          prompt: true,
          input_html: {
            data: { action: "form-reset#reset" }
          }
        f.input :depot_price,
          required: false,
          input_html: { data: { form_reset_target: "input" } }
      end
      ol "data-controller" => "form-reset" do
        f.input :delivery_cycle,
          collection: admin_delivery_cycles_collection,
          as: :select,
          prompt: true,
          input_html: {
            data: { action: "form-reset#reset" }
          }
        if feature?("absence")
          f.input :absences_included_annually,
            required: false,
            step: 1,
            input_html: {
              data: { form_reset_target: "input", "1p_ignore": true }
            },
            hint: t("formtastic.hints.membership.absences_included_annually_html")

          handbook_button(self, "absences", anchor: "absences-incluses")
        end
      end
    end
    f.inputs [
      Basket.model_name.human(count: 1),
      BasketComplement.kept.any? ? Membership.human_attribute_name(:memberships_basket_complements) : nil
    ].compact.to_sentence, "data-controller" => "form-reset" do
      f.input :basket_size,
        prompt: true,
        input_html: { data: { action: "form-reset#reset" } }
      f.input :basket_price,
        hint: true,
        required: false,
        input_html: { data: { form_reset_target: "input" } }
      if Current.acp.feature?("basket_price_extra")
        f.input :basket_price_extra, required: true, label: Current.acp.basket_price_extra_title
      end
      f.input :basket_quantity

      if BasketComplement.kept.any?
        f.has_many :memberships_basket_complements, allow_destroy: true do |ff|
          div "data-controller" => "form-reset" do
            ff.input :basket_complement,
              collection: admin_basket_complements_collection,
              prompt: true,
              input_html: { data: { action: "form-reset#reset" } }
            ff.input :price,
              hint: true,
              required: false,
              input_html: { data: { form_reset_target: "input" } }
            ff.input :quantity
            ff.input :delivery_cycle,
              as: :select,
              collection: admin_delivery_cycles_collection,
              include_blank: true,
              hint: true
          end
        end
      end
    end
    f.actions
  end

  permit_params \
    :member_id,
    :basket_size_id, :basket_price, :basket_price_extra, :basket_quantity, :baskets_annual_price_change,
    :depot_id, :depot_price, :delivery_cycle_id,
    :billing_year_division,
    :started_on, :ended_on, :renew, :renewal_annual_fee,
    :activity_participations_annual_price_change, :activity_participations_demanded_annually,
    :basket_complements_annual_price_change,
    :absences_included_annually,
    :new_config_from,
    memberships_basket_complements_attributes: [
      :id, :basket_complement_id,
      :price, :quantity,
      :delivery_cycle_id,
      :_destroy
    ]

  member_action :open_renewal, method: :post do
    resource.open_renewal!
    redirect_to resource
  end

  member_action :mark_renewal_as_pending, method: :post do
    resource.mark_renewal_as_pending!
    redirect_to resource
  end

  member_action :renew, method: :post do
    resource.renew!
    redirect_to resource
  end

  member_action :cancel, method: :post do
    resource.cancel!
    redirect_to resource
  end

  before_build do |membership|
    membership.activity_participations_annual_price_change = nil
    if member = Member.find_by(id: params[:member_id])
      membership.member_id ||= member.id
      membership.basket_size_id ||= member.waiting_basket_size&.id
      if member.waiting_basket_price_extra
        membership.basket_price_extra = member.waiting_basket_price_extra
      end
      if member.waiting_activity_participations_demanded_annually
        membership.activity_participations_demanded_annually = member.waiting_activity_participations_demanded_annually
      end
      membership.depot_id ||= member.waiting_depot&.id
      membership.delivery_cycle_id ||= member.waiting_delivery_cycle&.id
      member.members_basket_complements.each do |mbc|
        membership.memberships_basket_complements.build(
          basket_complement_id: mbc.basket_complement_id,
          quantity: mbc.quantity)
      end
      membership.billing_year_division = member.waiting_billing_year_division
    end
    if next_delivery = Delivery.next
      membership.started_on ||= [
        Date.current,
        next_delivery.fy_range.min,
        next_delivery.date.beginning_of_week
      ].max
      membership.ended_on ||= next_delivery.fy_range.max
    end
  end

  controller do
    include ApplicationHelper
    include TranslatedCSVFilename

    def apply_filtering(chain)
      super(chain).distinct
    end

    def apply_sorting(chain)
      super(chain).joins(:member).order("members.name", id: :desc)
    end
  end

  config.sort_order = "started_on_desc"
end
