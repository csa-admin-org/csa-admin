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
  scope :trial, if: -> { Current.org.trial_baskets? }
  scope :ongoing, default: true
  scope :future
  scope :past

  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :started_on
  filter :ended_on
  filter :id
  filter :member,
    as: :select,
    collection: -> { Member.joins(:memberships).order_by_name.distinct }
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
  filter :absences_included,
    if: proc { Current.org.feature?("absence") }
  filter :renewal_state,
    as: :select,
    collection: -> { renewal_states_collection }
  filter :billing_year_division,
    as: :select,
    collection: -> {
      divisions = Membership.pluck(:billing_year_division).uniq.sort
      divisions.map { |i| [ t("billing.year_division.x#{i}"), i ] }
    }
  filter :basket_price_extra,
    label: proc { Current.org.basket_price_extra_title },
    if: proc { Current.org.feature?("basket_price_extra") }
  filter :activity_participations_accepted,
    label: proc { Membership.human_attribute_name(activity_scoped_attribute(:activity_participations_accepted)) },
    if: proc { Current.org.feature?("activity") }
  filter :activity_participations_demanded,
    label: proc { Membership.human_attribute_name(activity_scoped_attribute(:activity_participations_demanded)) },
    if: proc { Current.org.feature?("activity") }
  filter :activity_participations_missing,
    as: :numeric,
    label: proc { Membership.human_attribute_name(activity_scoped_attribute(:activity_participations_missing)) },
    if: proc { Current.org.feature?("activity") }

  includes :member, :baskets, :delivery_cycle
  index do
    column :id, ->(m) { auto_link m, m.id }
    column :member, sortable: "members.name"
    column :started_on, ->(m) { auto_link m, l(m.started_on, format: :number) }, class: "text-right tabular-nums"
    column :ended_on, ->(m) { auto_link m, l(m.ended_on, format: :number) }, class: "text-right tabular-nums"
    if Current.org.feature?("activity")
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

  sidebar :activity_participations, only: :index, if: -> {
    Current.org.feature?("activity") && %w[
      activity_participations_accepted_eq
      activity_participations_accepted_gt
      activity_participations_accepted_lt
      activity_participations_demanded_eq
      activity_participations_demanded_gt
      activity_participations_demanded_lt
      activity_participations_missing_eq
      activity_participations_missing_gt
      activity_participations_missing_lt
    ].any? { |a| params.dig(:q, a).present? }
  } do
    side_panel activities_human_name do
      ids = collection.offset(nil).limit(nil).unscope(:includes, :joins, :order).pluck(:id)
      all = Membership.where(id: ids)
      %w[ accepted demanded missing ].each do |state|
        div number_line t("states.activity_participation.#{state}").capitalize, all.sum(&"activity_participations_#{state}".to_sym)
      end
    end
  end

  sidebar :billing, only: :index, if: -> { params.dig(:q, :during_year).present? } do
    side_panel t(".billing"), action: handbook_icon_link("billing", anchor: "memberships") do
      ids = collection.offset(nil).limit(nil).unscope(:includes, :joins, :order).pluck(:id)
      all = Membership.where(id: ids)
      total = all.sum(:price)
      invoiced = all.sum(:invoices_amount)
      missing = [ total - invoiced, 0 ].max
      div class: "space-y-4" do
        div do
          div number_line(t(".invoices_done"), cur(invoiced), bold: false)
          div number_line(t(".invoices_remaining"), cur(missing), bold: false)
          div number_line(t(".total"), cur(total), border_top: true)
        end
        if authorized?(:future_billing, Membership) && missing.positive? && all.minimum(:started_on).future?
          latest_created_at = Invoice.membership.maximum(:created_at)
          if !latest_created_at || latest_created_at < 5.seconds.ago
            div do
              button_to future_billing_all_memberships_path,
                params: { ids: ids },
                form: { class: "flex justify-center", data: { controller: "disable", disable_with_value: t(".invoicing") } },
                data: { confirm:  t(".future_billing#{"_with_annual_fee" if Current.org.annual_fee?}_confirm") },
                class: "action-item-button secondary small" do
                  icon("banknotes", class: "size-4 me-1.5") + t("active_admin.resource.show.future_billing")
                end
            end
          end
        end
      end
    end
  end

  collection_action :future_billing_all, method: :post do
    authorize!(:future_billing, Membership)

    Membership.where(id: params[:ids]).find_each do |membership|
      next unless Billing::InvoicerFuture.new(membership).billable?

      MembershipFutureBillingJob.perform_later(membership)
    end

    redirect_to collection_path, notice: t("active_admin.shared.sidebar_section.invoicing")
  end

  sidebar :basket_price_extra_title, only: :index, if: -> { Current.org.feature?("basket_price_extra") && params.dig(:q, :during_year).present? } do
    side_panel Current.org.basket_price_extra_title, action: handbook_icon_link("basket_price_extra") do
      coll =
        collection
          .unscope(:includes, :joins, :order)
          .offset(nil).limit(nil)
          .joins(:member)
          .merge(Member.no_salary_basket)
      baskets = Basket.billable.where(membership: coll)
      total = baskets.sum("quantity * price_extra")
      if coll.where("basket_price_extra < 0").any?
        div class: "flex justify-end" do
          sum = baskets.where("price_extra > 0").sum("quantity * price_extra")
          span cur(sum), class: "tabular-nums"
        end
        div class: "flex justify-end" do
          sum = baskets.where("price_extra < 0").sum("quantity * price_extra")
          span cur(sum), class: "tabular-nums"
        end
        div number_line(t(".amount"), cur(total), border_top: true)
      else
        div number_line(t(".amount"), cur(total))
      end
    end
  end

  sidebar :renewal, only: :index do
    side_panel t(".renewal"), action: handbook_icon_link("membership_renewal") do
      fy_year = params.dig(:q, :during_year).presence&.to_i || Current.fy_year
      renewal = MembershipsRenewal.new(fy_year)
      if !renewal.future_deliveries?
        div t(".no_next_year_deliveries_html",
          fiscal_year: renewal.next_fy.to_s,
          new_delivery_path: new_delivery_path)
      else
        div class: "space-y-4" do
          ul do
            li do
              link_to collection_path(scope: :all, q: { renewal_state_eq: :renewal_pending, during_year: renewal.fy_year }) do
                number_line t(".openable_renewals"), renewal.openable.count
              end
            end
            if MailTemplate.active_template(:membership_renewal)
              li do
                link_to collection_path(scope: :all, q: { renewal_state_eq: :renewal_opened, during_year: renewal.fy_year }) do
                  number_line t(".opened_renewals"), renewal.opened.count
                end
              end
            end
            li do
              link_to collection_path(scope: :all, q: { renewal_state_eq: :renewed, during_year: renewal.fy_year }) do
                number_line t(".renewed_renewals"), renewal.renewed.count
              end
            end
            li do
              end_of_year = renewal.fy.end_of_year
              renewal_canceled_count = Membership.where(renew: false).where(ended_on: end_of_year).count
              link_to collection_path(scope: :all, q: { renewal_state_eq: :renewal_canceled, during_year: renewal.fy_year, ended_on_gteq: end_of_year, ended_on_lteq: end_of_year }) do
                number_line t(".canceled_renewals"), renewal_canceled_count
              end
            end
          end
          if renewal.actionable?
            if renewal.renewing?
              div class: "flex justify-center items-center italic" do
                icon("arrow-path", class: "size-4 mr-2") + t(".renewing")
              end
            elsif renewal.opening?
              div class: "flex justify-center items-center italic" do
                icon("paper-airplane", class: "size-4 mr-2") + t(".opening")
              end
            else
              div class: "space-y-2" do
                if renewal.fy == Current.fiscal_year && authorized?(:open_renewal_all, Membership) && MailTemplate.active_template(:membership_renewal)
                  openable_count = renewal.openable.count
                  if openable_count.positive?
                    div do
                      button_to open_renewal_all_memberships_path,
                        params: { year: renewal.fy_year },
                        form: { class: "flex justify-center", data: { controller: "disable", disable_with_value: t(".opening") } },
                        class: "action-item-button secondary small", data: { confirm: t("active_admin.batch_actions.default_confirmation") } do
                          icon("paper-airplane", class: "size-4 mr-2") + t(".open_renewal_all_action", count: openable_count)
                        end
                    end
                  end
                end
                if authorized?(:renew_all, Membership)
                  div do
                    button_to renew_all_memberships_path,
                      params: { year: renewal.fy_year },
                      form: { class: "flex justify-center", data: { controller: "disable", disable_with_value: t(".renewing") } },
                      class: "action-item-button secondary small", data: { confirm: t("active_admin.batch_actions.default_confirmation") } do
                        icon("arrow-path", class: "size-4 mr-2") + t(".renew_all_action", count: renewal.renewable.count)
                      end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  collection_action :renew_all, method: :post do
    authorize!(:renew_all, Membership)
    year = params.require(:year).to_i
    MembershipsRenewal.new(year).renew_all!
    redirect_to collection_path, notice: t("active_admin.flash.renew_notice")
  rescue MembershipsRenewal::MissingDeliveriesError
    redirect_to collection_path,
      alert: t("active_admin.flash.renew_missing_deliveries_alert", next_year: MembershipsRenewal.new.next_fy)
  end

  collection_action :open_renewal_all, method: :post do
    authorize!(:open_renewal_all, Membership)
    year = params.require(:year).to_i
    MembershipsRenewal.new(year).open_all!
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
    column(:baskets_trial_count) { |m| m.baskets.count(&:trial?) }
    if feature?("absence")
      column(:absences_included)
      column(:baskets_absent_count) { |m| m.baskets.count(&:absent?) }
    end
    column(:basket_size) { |m| basket_size_description(m, text_only: true, public_name: false) }
    column(:basket_price) { |m| cur(m.basket_price) }
    if Current.org.feature?("basket_price_extra")
      column(Current.org.basket_price_extra_title) { |m|
        if Current.org.basket_price_extra_dynamic_pricing?
          m.basket_price_extra
        else
          cur(m.basket_price_extra)
        end
      }
      column("#{Current.org.basket_price_extra_title} - #{Membership.human_attribute_name(:total)}") { |m| cur(m.baskets_price_extra) }
    end
    column(:basket_quantity)
    if BasketComplement.kept.any?
      column(:basket_complements) { |m|
        basket_complements_description(m.memberships_basket_complements.includes(:basket_complement),
          text_only: true,
          public_name: false)
      }
      column(:basket_complements_price)
    end
    column(:depot) { |m| m.depot.name }
    if Depot.prices?
      column(:depot_price) { |m| cur(m.depot_price) }
    end
    column(:delivery_cycle) { |m| m.delivery_cycle.name }
    if Current.org.feature?("activity")
      column(activity_scoped_attribute(:activity_participations_demanded), &:activity_participations_demanded)
      column(activity_scoped_attribute(:activity_participations_accepted), &:activity_participations_accepted)
      column(activity_scoped_attribute(:activity_participations_missing), &:activity_participations_missing)
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
            shift_as_source: { target_basket: :delivery },
            baskets_basket_complements: :basket_complement
          ),
            row_html: ->(b) {
              classes = []
              classes << "bg-gray-200 dark:bg-gray-700" if b == next_basket
              classes << "text-gray-300 dark:text-gray-500 [&>td>a]:text-gray-300 [&>td>a]:decoration-gray-300 [&>td>a]:dark:text-gray-500 [&>td>a]:dark:decoration-gray-500" if b.absent? || b.empty?
              classes << "line-through" if !b.billable? || b.empty?
              { class: classes.join(" "), data: { "hover-id": dom_id(b) } }
            },
            class: "table-auto"
          ) do
            column(:delivery, class: "md:w-32") { |b| link_to b.delivery.display_name(format: :number), b.delivery }
            column(:description) { |b| b.shifted? ? b.shift_as_source.description : b.description }
            column(:depot)
            if m.baskets.where(state: [ :absent, :trial ]).any?
              column(class: "text-right") do |b|
                div class: "inline-flex items-center justify-between gap-2 " do
                  ic = "".html_safe
                  if b.shifted?
                    ic += tag.div(data: {
                      controller: "hover",
                      action: "mouseenter->hover#show mouseleave->hover#hide",
                      "hover-id-value": dom_id(b.shift_as_source.target_basket),
                      "hover-class-value": %w[bg-teal-100 dark:bg-teal-900]
                    }) do
                      description = t(".basket_shift_tooltip",
                        target_date: l(b.shift_as_source.target_basket.delivery.date, format: :short))
                      tooltip(dom_id(b), description, icon_name: "redo")
                    end
                  end
                  if b.shift_declined?
                    ic += tag.div { tooltip(dom_id(b), t(".basket_shift_declined_tooltip"), icon_name: "redo-off") }
                  end
                  ic + display_basket_state(b)
                end
              end
            end
            column(nil) { |b|
              if authorized?(:update, b)
                div class: "data-table-resource-actions" do
                  link_to edit_basket_path(b), title: t(".edit") do
                    icon "pencil-square", class: "size-5"
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
            row(:fiscal_year)
            row(:period) { m.display_period }
            row(:created_at) { l m.created_at, format: :medium }
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
              delivery_cycle_link(m.delivery_cycle, fy_year: m.fy_year)
            }
          end
        end

        if feature?("absence") && (m.absences_included_annually.positive? || Current.org.basket_shift_enabled? || m.basket_shifts_count.positive?)
          panel link_to(Absence.model_name.human(count: 2), absences_path(q: { member_id_eq: m.member_id, during_year: m.fy_year }, scope: :all)), count: m.baskets.absent.count, class: "absence-panel" do
            attributes_table do
              if m.absences_included_annually.positive?
                row(:absences_included, class: "text-right") {
                  used = m.baskets.definitely_absent.count
                  link_to absences_path(q: { member_id_eq: m.member_id, during_year: m.fy_year }, scope: :all) do
                    t(".absences_used", count: used, limit: m.absences_included)
                  end
                }
              end
              if Current.org.basket_shift_enabled? || m.basket_shifts_count.positive?
                row(:basket_shifts, class: "text-right") {
                  if Current.org.basket_shifts_annually&.positive?
                    t(".basket_shifts_used", count: m.basket_shifts_count, limit: Current.org.basket_shifts_annually)
                  else
                    m.basket_shifts_count
                  end
                }
              end
            end
          end
        end

        if Current.fiscal_year >= m.fiscal_year
          panel Membership.human_attribute_name(:renew), state: m.renewal_state, action: handbook_icon_link("membership_renewal") do
            attributes_table do
              if m.renewed?
                row(:renewed_at) { l m.renewed_at.to_date  }
                row(:renewed_membership)
                row :renewal_note
              elsif m.canceled?
                if Current.org.annual_fee?
                  row(:renewal_annual_fee) {
                    status_tag(!!m.renewal_annual_fee)
                    span { cur(m.renewal_annual_fee) }
                  }
                end
                row :renewal_note
                if m.ended_on == Current.fiscal_year.end_of_year && authorized?(:mark_renewal_as_pending, m)
                  div class: "mt-2 flex items-center justify-center gap-4" do
                    div do
                      button_to mark_renewal_as_pending_membership_path(m),
                        form: {
                          data: { controller: "disable", disable_with_value: t("formtastic.processing") }
                        },
                        class: "action-item-button small secondary",
                        data: { confirm: t(".confirm") } do
                          icon("arrow-uturn-left", class: "size-4 me-1.5") + t(".mark_renewal_as_pending")
                        end
                    end
                  end
                end
              elsif m.renewal_opened?
                row(:renewal_opened_at) { l m.renewal_opened_at.to_date }
                if Current.org.open_renewal_reminder_sent_after_in_days?
                  row(:renewal_reminder_sent_at) {
                    if m.renewal_reminder_sent_at
                      l m.renewal_reminder_sent_at.to_date
                    end
                  }
                end
                div class: "mt-2 flex items-center justify-center gap-4" do
                  if authorized?(:renew, m)
                    div do
                      button_to renew_membership_path(m),
                        form: {
                          data: { controller: "disable", disable_with_value: t("formtastic.processing") }
                        },
                        data: { confirm: t(".confirm") },
                        class: "action-item-button small secondary",
                        disabled: !m.can_renew? do
                          icon("arrow-path", class: "size-4 me-1.5") + t(".renew")
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
                          icon("x-circle", class: "size-4 me-1.5") + t(".cancel_renewal")
                        end
                    end
                  end
                end
              else
                div class: "mt-2 flex items-center justify-center gap-4" do
                  if Delivery.any_in_year?(m.fy_year + 1)
                    if authorized?(:open_renewal, m) && MailTemplate.active_template(:membership_renewal)
                      div do
                        button_to open_renewal_membership_path(m),
                          form: {
                            data: { controller: "disable", disable_with_value: t("formtastic.processing") }
                          },
                          data: { confirm: t(".confirm") },
                          class: "action-item-button small secondary" do
                            icon("paper-airplane", class: "size-4 me-1.5") + t(".open_renewal")
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
                            icon("arrow-path", class: "size-4 me-1.5") + t(".renew")
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
                          icon("x-circle", class: "size-4 me-1.5") + t(".cancel_renewal")
                        end
                    end
                  end
                end
              end
            end
          end
        end

        panel Membership.human_attribute_name(:amount), class: "full-table" do
          if m.member.salary_basket?
            div(class: "missing-data") { t(".salary_basket") }
          elsif m.baskets_count.zero?
            div(class: "missing-data") { t(".no_baskets") }
          else
            attributes_table do
              if m.basket_sizes_price.nonzero?
                row(Basket.model_name.human(count: m.baskets_count), class: "text-right tabular-nums") {
                  display_price_description(m.basket_sizes_price, basket_sizes_price_info(m, m.baskets))
                }
              end
              if m.baskets_annual_price_change.nonzero?
                row(t(".baskets_annual_price_change"), class: "text-right tabular-nums") {
                  cur(m.baskets_annual_price_change, unit: false)
                }
              end
              if m.basket_complements.any? && m.basket_complements_price.nonzero?
                row(MembershipsBasketComplement.model_name.human(count: m.basket_complements.count), class: "text-right tabular-nums") {
                  display_price_description(
                    m.basket_complements_price,
                    membership_basket_complements_price_info(m))
                }
              end
              if m.basket_complements_annual_price_change.nonzero?
                row(t(".basket_complements_annual_price_change"), class: "text-right tabular-nums") {
                  cur(m.basket_complements_annual_price_change, unit: false)
                }
              end
              if Current.org.feature?("basket_price_extra") && (m.basket_price_extra.nonzero? || m.baskets.any? { |b| b.price_extra.nonzero? })
                row(:basket_price_extra_title, class: "text-right tabular-nums") {
                  description = baskets_price_extra_info(m, m.baskets, highlight: true)
                  display_price_description(m.baskets_price_extra, description)
                }
              end
              if m.depots_price.nonzero?
                row(Depot.model_name.human(count: m.baskets_count), class: "text-right tabular-nums") {
                  display_price_description(m.depots_price, depots_price_info(m.baskets))
                }
              end
              if m.deliveries_price.nonzero?
                row(Delivery.model_name.human(count: 2), class: "text-right tabular-nums") {
                  display_price_description(m.deliveries_price, delivery_cycle_price_info(m.baskets))
                }
              end
              if Current.org.feature?("activity") && m.activity_participations_annual_price_change.nonzero?
                row(t_activity(".activity_participations_annual_price_change"), class: "text-right tabular-nums") {
                  cur(m.activity_participations_annual_price_change, unit: false)
                }
              end
              row(:price, class: "border-solid border-0 border-t border-gray-800 dark:border-gray-200 text-right font-bold tabular-nums") {
                cur(m.price, format: "%u %n")
              }
            end
          end
        end

        panel t(".billing"), action: handbook_icon_link("billing", anchor: "memberships") do
          attributes_table do
            row(:billing_year_division, class: "text-right") { t("billing.year_division.x#{m.billing_year_division}") }
            row(:invoices_amount, class: "text-right tabular-nums") {
              link_to(
                cur(m.invoices_amount),
                invoices_path(scope: :all, q: {
                  member_id_eq: resource.member_id,
                  membership_eq: resource.id,
                  entity_type_in: "Membership"
                }))
            }
            row(:missing_invoices_amount, class: "text-right tabular-nums") { cur(m.missing_invoices_amount) }
            if resource.billable?
              row(:next_invoice_on) {
                if Current.org.recurring_billing?
                  invoicer = Billing::Invoicer.new(resource.member, membership: resource, date: Date.tomorrow)
                  if invoicer.next_date
                    div class: "flex items-center justify-end gap-2" do
                      span do
                        l(invoicer.next_date, format: :medium)
                      end
                      if authorized?(:recurring_billing, resource.member) && Billing::Invoicer.new(resource.member, membership: resource).billable?
                        div do
                          button_to t(".recurring_billing"), recurring_billing_member_path(resource.member),
                            form: {
                              data: { controller: "disable", disable_with_value: t("formtastic.processing") },
                              class: "inline"
                            },
                            data: { confirm: t(".recurring_billing_confirm") },
                            class: "action-item-button small secondary"
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
          if authorized?(:future_billing, resource) && resource.future?
            invoicer = Billing::InvoicerFuture.new(resource)
            if invoicer.billable?
              div class: "mt-2 flex items-center justify-center gap-4" do
                button_to future_billing_membership_path(resource),
                  form: {
                    data: { controller: "disable", disable_with_value: t("formtastic.processing") },
                    class: "inline"
                  },
                  data: { confirm:  t(".future_billing#{"_with_annual_fee" if resource.member.annual_fee&.positive?}_confirm") },
                  class: "action-item-button small secondary" do
                    icon("banknotes", class: "size-4 me-1.5") + t(".future_billing")
                  end
              end
            end
          end
        end

        if Current.org.feature?("activity")
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
                      m.member.activity_participations.during_year(m.fiscal_year.year).send(scope).sum(:participants_count))
                  end
                end
              end
              li class: "w-1/3" do
                link_to invoices_path(scope: :all, q: { entity_type_in: "ActivityParticipation", member_id_eq: resource.member_id, missing_participations_fiscal_year: resource.fiscal_year.year }) do
                  counter_tag(
                    Membership.human_attribute_name(:activity_participations_paid),
                    m.member.invoices.not_canceled.activity_participations_fiscal_year(m.fiscal_year).sum(:missing_activity_participations_count))
                end
              end
            end
            if authorized?(:clear_activity_participations_demanded, m)
              div class: "mt-3 flex items-center justify-center gap-4" do
                button_to clear_activity_participations_demanded_membership_path(m),
                  form: { class: "inline" },
                  data: { confirm: t_activity(".clear_activity_participations_demanded_confirm") },
                  class: "action-item-button small secondary" do
                    icon("x-circle", class: "size-4 me-1.5") + t_activity(".clear_activity_participations_demanded")
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
        collection: Member.order_by_name.map { |d| [ d.name, d.id ] },
        prompt: true
      div class: "single-line" do
        f.input :started_on, as: :date_picker
        f.input :ended_on, as: :date_picker
      end
    end

    if Current.org.annual_fee? && f.object.canceled?
      f.inputs Membership.human_attribute_name(:renew) do
        f.input :renewal_annual_fee
      end
    end

    if Current.org.feature?("activity")
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
    f.inputs Delivery.model_name.human(count: 2) do
       ol "data-controller" => "form-reset" do
        f.input :depot,
          collection: admin_depots_collection,
          prompt: true,
          input_html: {
            data: { action: "form-reset#reset" }
          }
        if Depot.prices?
          f.input :depot_price,
            required: false,
            input_html: { data: { form_reset_target: "input" } }
        end
      end
      ol "data-controller" => "form-reset", class: "mt-6" do
        f.input :delivery_cycle,
          collection: admin_delivery_cycles_collection,
          as: :select,
          prompt: true,
          input_html: {
            data: { action: "form-reset#reset" }
          }
        if DeliveryCycle.prices? || f.object.delivery_cycle_price&.positive?
          f.input :delivery_cycle_price,
            required: false,
            input_html: { data: { form_reset_target: "input" } }
        end
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
        collection: admin_basket_sizes_collection,
        prompt: true,
        input_html: { data: { action: "form-reset#reset" } }
      f.input :basket_price,
        hint: true,
        required: false,
        input_html: { data: { form_reset_target: "input" } }
      if Current.org.feature?("basket_price_extra")
        f.input :basket_price_extra, required: true, label: Current.org.basket_price_extra_title
      end
      f.input :basket_quantity

      if BasketComplement.kept.any?
        f.has_many :memberships_basket_complements, allow_destroy: true, data: { controller: "form-reset" } do |ff|
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
    f.actions
  end

  permit_params \
    :member_id,
    :basket_size_id, :basket_price, :basket_price_extra, :basket_quantity, :baskets_annual_price_change,
    :depot_id, :depot_price, :delivery_cycle_id, :delivery_cycle_price,
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

  member_action :clear_activity_participations_demanded, method: :post do
    resource.clear_activity_participations_demanded!
    redirect_to resource
  end

  member_action :future_billing, method: :post do
    if invoice = Billing::InvoicerFuture.invoice(resource)
      redirect_to invoice
    else
      redirect_back fallback_location: resource
    end
  end

  collection_action :clear_all_activity_participations_demanded, method: :post do
    authorize!(:update, Membership)
    Membership.during_year(params[:year]).find_each do |m|
      m.clear_activity_participations_demanded!
    end
    redirect_back fallback_location: activity_participations_path(q: { during_year: Current.fiscal_year.year })
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

  before_action only: :index do
    if params.dig(:q, :during_year).present? && params.dig(:q, :during_year).to_i < Current.fy_year
      params[:scope] ||= "all"
    end
  end

  controller do
    include ApplicationHelper
    include TranslatedCSVFilename

    def apply_filtering(chain)
      super(chain).distinct
    end

    def apply_sorting(chain)
      super(chain).joins(:member).merge(Member.order_by_name)
    end
  end

  order_by("members.name") do |clause|
    Member
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.sort_order = "started_on_desc"
end
