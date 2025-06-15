# frozen_string_literal: true

2# frozen_string_literal: true

ActiveAdmin.register Member do
  menu priority: 2

  scope :all
  scope :pending
  scope :waiting
  scope :active, default: true
  scope :support, if: -> { Current.org.member_support? }
  scope :inactive

  filter :id
  filter :name_cont, label: -> { Member.human_attribute_name(:name) }
  filter :address_cont, label: -> { Member.human_attribute_name(:address) }
  filter :note_cont, label: -> { Member.human_attribute_name(:note) }
  filter :with_phone, as: :string
  filter :with_email, as: :string
  filter :with_waiting_depots,
    label: -> { Member.human_attribute_name(:waiting_depot) },
    as: :select,
    collection: -> { admin_depots_collection },
    if: proc { params[:scope] == "waiting" && Current.org.member_form_mode == "membership" }
  filter :shop_depot,
    as: :select,
    collection: -> { admin_depots_collection },
    if: proc { params[:scope] != "inactive" && feature?("shop") }
  filter :city, as: :select, collection: -> {
    Member.pluck(:city).uniq.map(&:presence).compact.sort
  }
  filter :country_code, as: :select, collection: -> {
    country_codes = Member.pluck(:country_code).uniq.map(&:presence).compact.sort
    countries_collection(country_codes)
  }
  filter :salary_basket,
    as: :boolean,
    if: proc { params[:scope].in? [ "active", nil ] }
  filter :annual_fee,
    if: proc { Current.org.annual_fee? }
  filter :sepa, as: :boolean, if: ->(a) { Current.org.sepa? }

  includes :shop_depot, next_basket: [ :basket_size, :depot, :membership, baskets_basket_complements: :basket_complement ]
  index do
    column :id, ->(member) { auto_link member, member.id }
    if params[:scope] == "waiting"
      @waiting_started_ats ||= Member.waiting.order(:waiting_started_at).pluck(:waiting_started_at)
      column "#", ->(member) {
        @waiting_started_ats.index(member.waiting_started_at) + 1
      }, sortable: :waiting_started_at, class: "text-right"
    end
    column :name, ->(member) { auto_link member }
    case Current.org.member_form_mode
    when "membership"
      case params[:scope]
      when "pending", "waiting"
        column Depot.model_name.human(count: Current.org.allow_alternative_depots? ? 2 : 1), ->(member) {
          ([ member.waiting_depot ] + member.waiting_alternative_depots)
            .compact.map(&:name).to_sentence.truncate(50)
        }
      when nil, "all", "active"
        column :next_basket, ->(member) {
          if next_basket = member.next_basket
            a href: url_for(member.next_basket.membership) do
              content_tag(:span, [
                next_basket.description,
                next_basket.depot.name
              ].join(" / "))
            end
            status_tag(:trial, class: "ms-1") if next_basket.trial?
          end
        }
      end
    when "shop"
      column(:shop_depot) unless params[:scope] == "inactive"
    end
    if params[:scope] == "inactive"
      column :city, ->(member) { member.city? ? "#{member.city} (#{member.zip})" : "–" }
    end
    column :state, ->(member) { status_tag(member.state) }, class: "text-right"
    actions
  end

  csv do
    column(:id)
    column(:name)
    column(:state, &:state_i18n_name)
    column(:emails) { |m| m.emails_array.join(", ") }
    column(:phones) { |m| m.phones_array.map(&:phony_formatted).join(", ") }
    if Current.org.languages.many?
      column(:language) { |m| t("languages.#{m.language}") }
    end
    column(:address)
    column(:zip)
    column(:city)
    column(:country_code)
    column(:profession)
    column(:billing_email)
    column(:billing_name)
    column(:billing_address)
    column(:billing_zip)
    column(:billing_city)
    if Current.org.annual_fee?
      column(:annual_fee) { |m| cur(m.annual_fee) }
    end
    if Current.org.share?
      column(:shares_number)
      column(:shares_info)
    end
    column(:salary_basket, &:salary_basket?)
    column(:waiting_started_at)
    column(:waiting_basket_size) { |m| m.waiting_basket_size&.name }
    if BasketComplement.kept.any?
      column(:waiting_basket_complements) { |m|
        basket_complements_description(
          m.members_basket_complements.includes(:basket_complement),
          text_only: true,
          public_name: false)
      }
    end
    if feature?("activity")
      column(I18n.t("active_admin.shared.sidebar_section.waiting_attribute", attribute: activities_human_name)) { |m|
        cur(m.waiting_activity_participations_demanded_annually)
      }
    end
    if feature?("basket_price_extra")
      column(I18n.t("active_admin.shared.sidebar_section.waiting_attribute", attribute: Current.org.basket_price_extra_title)) { |m|
        cur(m.waiting_basket_price_extra)
      }
    end
    column(:waiting_depot) { |m| m.waiting_depot&.name }
    column(:waiting_delivery_cycle) { |m| m.waiting_delivery_cycle&.name }
    if Current.org.allow_alternative_depots?
      column(:waiting_alternative_depot_ids) { |m|
        m.waiting_alternative_depots.map(&:name).to_sentence
      }
    end
    if feature?("contact_sharing")
      column(:contact_sharing)
    end
    if feature?("shop")
      column(:shop_depot) { |m| m.use_shop_depot? && m.shop_depot&.name }
    end
    column(:food_note)
    column(:come_from)
    column(:delivery_note)
    column(:note)
    column(:validated_at)
    column(:created_at)
    column(:invoices_amount) { |m| cur m.invoices_amount }
    column(:payments_amount) { |m| cur m.payments_amount }
    column(:balance_amount) { |m| cur m.balance_amount }
  end

  sidebar_handbook_link("members")

  show do |member|
    columns do
      column do
        if next_basket = member.next_basket
          panel link_to(Member.human_attribute_name(:next_basket), next_basket.membership).html_safe do
            attributes_table do
              if next_basket.trial?
                row(:state) { status_tag(:trial) }
              end
              row(:basket_size) { basket_size_description(member.next_basket, text_only: true, public_name: false) }
              if BasketComplement.kept.any?
                row(Membership.human_attribute_name(:memberships_basket_complements)) {
                  basket_complements_description(member.next_basket.baskets_basket_complements, text_only: true, public_name: false)
                }
              end
              row(:depot) { link_to next_basket.depot.name, next_basket.depot  }
              row(:delivery) { link_to next_basket.delivery.display_name(format: :long), next_basket.delivery }
              if Current.org.feature?("shop")
                shop_order = next_basket.delivery.shop_orders.all_without_cart.find_by(member_id: member.id)
                row(t("shop.title")) { auto_link shop_order }
              end
              row(:delivery_cycle) {
                delivery_cycle_link(next_basket.membership.delivery_cycle,
                  fy_year: next_basket.membership.fy_year)
              }
              row(:membership) { link_to "##{next_basket.membership.id} (#{next_basket.membership.fiscal_year})", next_basket.membership }
            end
          end
        end

        if member.pending? || member.waiting?
          panel t(".waiting_membership") do
            div class: "px-2" do
              attributes_table do
                row(:basket_size) { auto_link member.waiting_basket_size }
                if BasketComplement.kept.any?
                  row(Membership.human_attribute_name(:memberships_basket_complements)) {
                    basket_complements_description(
                      member.members_basket_complements.includes(:basket_complement), text_only: true, public_name: false)
                  }
                end
                if feature?("activity")
                  row(activities_human_name) { member.waiting_activity_participations_demanded_annually }
                end
                if feature?("basket_price_extra")
                  row(Current.org.basket_price_extra_title) { cur(member.waiting_basket_price_extra) }
                end
                row(:depot) { auto_link member.waiting_depot }
                row(:delivery_cycle) { delivery_cycle_link(member.waiting_delivery_cycle) }
                if Current.org.allow_alternative_depots?
                  row(:waiting_alternative_depot_ids) {
                    member.waiting_alternative_depots.map(&:name).to_sentence
                  }
                end
                if member.waiting_billing_year_division?
                  row(:billing_year_division) {
                    t("billing.year_division.x#{member.waiting_billing_year_division}")
                  }
                end
                if member.waiting?
                  row :waiting_started_at
                end
              end
            end
          end
        end

        all_memberships_path = memberships_path(q: { member_id_eq: member.id }, scope: :all)
        memberships = member.memberships.order(started_on: :desc)
        memberships_count = memberships.count
        panel link_to(Membership.model_name.human(count: 2), all_memberships_path), count: memberships_count do
          if memberships_count.zero?
            div(class: "missing-data") { t(".no_memberships") }
          else
            table_for(memberships.limit(3), class: "table-memberships") do
              column(:period) { |m| auto_link m, membership_period(m, format: :number) }
              if Current.org.feature?("activity")
                column(activities_human_name, class: "text-right") { |m|
                  auto_link m, "#{m.activity_participations_accepted} / #{m.activity_participations_demanded}"
                }
              end
              column(:baskets_count, class: "text-right") { |m|
                auto_link m, "#{m.past_baskets_count} / #{m.baskets_count}"
              }
            end
            if memberships_count > 3
              div show_more_link(all_memberships_path)
            end
          end
        end

        if Current.org.feature?("shop")
          all_orders_path = shop_orders_path(q: { member_id_eq: member.id }, scope: :all_without_cart)
          orders =
            member
              .shop_orders
              .all_without_cart
              .includes(:delivery, invoice: { pdf_file_attachment: :blob })
              .order(created_at: :desc)
          orders_count = orders.count
          panel link_to(t("shop.title_orders", count: 2), all_orders_path), count: orders_count do
            if orders_count.zero?
              div do
                div(class: "missing-data") { t(".no_orders") }
              end
            else
              table_for(orders.limit(3), class: "table-auto") do
                column(:id) { |o| auto_link o, o.id }
                column(:date) { |o| l(o.date, format: :number) }
                column(:delivery) { |o| link_to o.delivery.display_name(format: :number), o.delivery }
                column(:amount, class: "text-right") { |o| cur(o.amount) }
                column(:status, class: "text-right") { |o| status_tag o.state, label: o.state_i18n_name }
              end
              if orders_count > 3
                div show_more_link(all_orders_path)
              end
            end
          end
        end

        if Current.org.feature?("activity")
          all_activity_participations_path =
            activity_participations_path(q: { member_id_eq: member.id }, scope: :all)
          activity_participations =
            member.activity_participations.includes(:activity)
              .order("activities.date DESC, activities.start_time DESC")
          activity_participations_count = activity_participations.count
          panel link_to(activities_human_name, all_activity_participations_path), count: activity_participations_count do
            if activity_participations_count.zero?
              div(class: "missing-data") { t_activity(".no_activities") }
            else
              table_for(activity_participations.limit(6), class: "table-auto") do
                column(Activity.model_name.human) { |ap|
                  auto_link ap, ap.activity.name
                }
                column(:participants_short, class: "text-right") { |ap| ap.participants_count }
                column(:state, class: "text-right") { |ap| status_tag(ap.state) }
              end
              if activity_participations_count > 6
                div show_more_link(all_activity_participations_path)
              end
            end
          end
        end

        all_invoices_path = invoices_path(q: { member_id_eq: member.id }, scope: :all)
        invoices = member.invoices.includes(pdf_file_attachment: :blob).order(date: :desc, id: :desc)
        invoices_count = invoices.count
        panel link_to(Invoice.model_name.human(count: 2), all_invoices_path), count: invoices.count do
          if invoices_count.zero?
            div(class: "missing-data") { t(".no_invoices") }
          else
            table_for(invoices.limit(10), class: "table-auto") do
              column(:id, class: "") { |i| auto_link i, i.id }
              column(:date, class: "text-right") { |i| l(i.date, format: :number) }
              column(:amount, class: "text-right") { |i|
                (content_tag(:span, cur(i.paid_amount) + " /", class: "text-sm whitespace-nowrap text-gray-500") + " " +
                  content_tag(:span, cur(i.amount), class: "whitespace-nowrap")).html_safe
              }
              column(:status, class: "text-right") { |i| status_tag i.state }
            end
            if invoices_count > 10
              div show_more_link(all_invoices_path)
            end
          end
        end

        all_payments_path = payments_path(q: { member_id_eq: member.id }, scope: :all)
        payments = member.payments.includes(:invoice).reorder(date: :desc)
        payments_count = payments.count
        panel link_to(Payment.model_name.human(count: 2), all_payments_path), count: payments_count do
          if payments_count.zero?
            div(class: "missing-data") { t(".no_payments") }
          else
            table_for(payments.limit(10), class: "table-auto") do
              column(:id) { |p| auto_link p, p.id }
              column(:date, class: "text-right") { |p| l(p.date, format: :number) }
              column(:invoice_id, class: "text-right") { |p| p.invoice_id ? auto_link(p.invoice, p.invoice_id) : "–" }
              column(:amount, class: "text-right") { |p| cur(p.amount) }
              column(:type, class: "text-right") { |p| status_tag p.state }
            end
            if payments_count > 10
              div show_more_link(all_payments_path)
            end
          end
        end

        if Current.org.feature?("absence")
          all_absences_path = absences_path(q: { member_id_eq: member.id }, scope: :all)
          absences = member.absences.order(started_on: :desc)
          absences_count = absences.count
          panel link_to(Absence.model_name.human(count: 2), all_absences_path), count: absences_count do
            if absences_count.zero?
              div(class: "missing-data") { t(".no_absences") }
            else
              table_for(absences.limit(3), class: "table-absences") do
                column(:started_on) { |a| auto_link a, l(a.started_on) }
                column(:ended_on) { |a| auto_link a, l(a.ended_on) }
              end
              if absences_count > 3
                div show_more_link(all_absences_path)
              end
            end
          end
        end
      end

      column do
        panel t(".details") do
          attributes_table do
            row(:id)
            row(:created_at) { l(member.created_at, format: :medium) }
            row(:validated_at) { member.validated_at ? l(member.validated_at, format: :medium) : nil }
            row :validator
          end
        end
        if Current.org.feature?("shop") && member.use_shop_depot?
          panel t("shop.title") do
            attributes_table do
              row(:depot) { member.shop_depot }
            end
          end
        end
        panel Member.human_attribute_name(:contact) do
          attributes_table do
            row :name
            row(:emails) { display_emails_with_link(self, member.emails_array) }
            row(:phones) { display_phones_with_link(self, member.phones_array) }
            row(Member.human_attribute_name(:address)) { display_address(member) }
            if Current.org.languages.many?
              row(:language) { t("languages.#{member.language}") }
            end
            if Current.org.feature?("contact_sharing")
              row(:contact_sharing) { status_tag(member.contact_sharing) }
            end
          end
        end
        panel t(".billing"), action: handbook_icon_link("billing") do
          attributes_table do
            if member.salary_basket?
              row(:salary_basket, class: "text-right") { status_tag(member.salary_basket) }
            end
            if member.billing_email?
              row(t(".email"), class: "text-right") { display_email_with_link(self, member.billing_email) }
            end
            if member.different_billing_info
              row(:name, class: "text-right") { member.billing_name }
              row(:address, class: "text-right") { display_billing_address(member) }
            end
            if Current.org.annual_fee? || member.annual_fee
              row(:annual_fee, class: "text-right tabular-nums") { cur member.annual_fee }
            end
            row(:invoices_amount, class: "text-right tabular-nums") {
              link_to(
                cur(member.invoices_amount),
                invoices_path(q: { member_id_eq: member.id }, scope: :all))
            }
            row(:payments_amount, class: "text-right tabular-nums") {
              link_to(
                cur(member.payments_amount),
                payments_path(q: { member_id_eq: member.id }, scope: :all))
            }
            row(:balance_amount, class: "text-right tabular-nums") {
              if member.balance_amount.zero?
                cur member.balance_amount
              else
                span class: "font-bold" do
                  cur member.balance_amount
                end
              end
            }
            invoicer = Billing::Invoicer.new(member, date: Date.tomorrow)
            if invoicer.next_date
              row(:next_invoice_on, class: "text-right") {
                if Current.org.recurring_billing?
                  div class: "flex items-center justify-end gap-2" do
                    if invoicer.next_date
                      span do
                        l(invoicer.next_date, format: :medium)
                      end
                      if authorized?(:recurring_billing, member) && Billing::Invoicer.new(member).billable?
                        div do
                          button_to t(".recurring_billing"), recurring_billing_member_path(member),
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
        end

        if Current.org.sepa?
          panel t(".billing") + " (SEPA)" do
            attributes_table do
              row(:iban) { member.iban_formatted }
              row(:sepa_mandate_id) {
                if member.sepa_mandate_id?
                  member.sepa_mandate_id + " (#{l(member.sepa_mandate_signed_on)})"
                end
              }
            end
          end
        end

        if Current.org.share?
          panel t("active_admin.resource.new.shares") do
            attributes_table do
              row(Organization.human_attribute_name(:shares_number)) { display_shares_number(member) }
              row(:shares_info) { member.shares_info }
              invoicer = Billing::InvoicerShare.new(member)
              if invoicer.billable?
                row(:next_invoice_on) {
                  if Current.org.recurring_billing?
                    if invoicer.next_date
                      span class: "next_date" do
                        l(invoicer.next_date, format: :medium)
                      end
                      if authorized?(:force_share_billing, member)
                        button_to t(".recurring_billing"), force_share_billing_member_path(member),
                          form: {
                            data: { controller: "disable", disable_with_value: t("formtastic.processing") },
                            class: "inline"
                          },
                          data: { confirm: t(".recurring_billing_confirm") }
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
        end

        panel t(".notes") do
          attributes_table do
            row :profession
            row(:come_from) { text_format(member.come_from) }
            row :delivery_note
            row(:food_note) { text_format(member.food_note) }
            row(:note) { text_format(member.note) }
          end
        end

        active_admin_comments_for(member)
      end
    end
  end

  form do |f|
    f.inputs Member.human_attribute_name(:contact) do
      f.input :name
      f.input :emails, as: :string
      f.input :phones, as: :string
      f.input :address
      div class: "single-line" do
        f.input :zip, wrapper_html: { class: "md:w-50" }
        f.input :city, wrapper_html: { class: "w-full" }
      end
      f.input :country_code,
        as: :select,
        collection: countries_collection
      language_input(f)
      if Current.org.feature?("contact_sharing")
        f.input :contact_sharing
      end
    end

    if member.pending? || member.waiting?
      f.inputs t("active_admin.resource.show.waiting_membership") do
        f.input :waiting_basket_size,
          label: BasketSize.model_name.human,
          collection: admin_basket_sizes_collection,
          required: false
        if feature?("activity")
          f.input :waiting_activity_participations_demanded_annually,
            label: "#{activities_human_name} (#{t('.full_year')})",
            min: 0,
            hint: t("formtastic.hints.membership.activity_participations_demanded_annually_html"),
            required: false
        end
        if Current.org.feature?("basket_price_extra")
          f.input :waiting_basket_price_extra,
            label: Current.org.basket_price_extra_title,
            required: false
        end
        f.input :waiting_depot,
          label: Depot.model_name.human,
          required: false,
          input_html: {
            data: {
              controller: "form-select-options",
              action: "form-select-options#update",
              form_select_options_target_param: "member_waiting_delivery_cycle_id"
            }
          },
          collection: admin_depots_collection(->(d) {
            { data: { form_select_options_values_param: d.delivery_cycle_ids.join(",") } }
          })
        f.input :waiting_delivery_cycle,
          label: DeliveryCycle.model_name.human,
          as: :select,
          collection: admin_delivery_cycles_collection,
          disabled: f.object.waiting_depot && DeliveryCycle.visible? ? (DeliveryCycle.pluck(:id) - f.object.waiting_depot.delivery_cycle_ids) : []
        f.input :waiting_billing_year_division,
          label: Membership.human_attribute_name(:billing_year_division),
          as: :select,
          collection: billing_year_divisions_collection,
          prompt: true
        if Depot.kept.many?
          f.input :waiting_alternative_depot_ids,
            collection: admin_depots,
            as: :check_boxes,
            hint: false
        end
        if BasketComplement.kept.any?
          f.has_many :members_basket_complements, allow_destroy: true do |ff|
            ff.input :basket_complement,
              collection: admin_basket_complements_collection,
              prompt: true
            ff.input :quantity
          end
        end
      end
    end
    if Current.org.feature?("shop") && !member.current_or_future_membership
      f.inputs t("shop.title") do
        f.input :shop_depot,
          label: Depot.model_name.human,
          required: false,
          collection: admin_depots_collection
      end
    end

    f.inputs t("active_admin.resource.show.billing"), data: { controller: "visibility" } do
      f.input :billing_email, type: :email, label: t(".email")
      f.input :different_billing_info, input_html: { data: { action: "visibility#toggle" } }
      ol class: "-mt-4 #{f.object.different_billing_info ? "" : "hidden"}", data: { "visibility-target" => "element" } do
        f.input :billing_name, label: Member.human_attribute_name(:name), required: true, input_html: { disabled: !f.object.different_billing_info }
        f.input :billing_address, label: Member.human_attribute_name(:address), required: true, input_html: { disabled: !f.object.different_billing_info }
        div class: "single-line" do
          f.input :billing_zip, label: Member.human_attribute_name(:zip), required: true, input_html: { disabled: !f.object.different_billing_info }, wrapper_html: { class: "md:w-50" }
          f.input :billing_city, label: Member.human_attribute_name(:city), required: true, input_html: { disabled: !f.object.different_billing_info }, wrapper_html: { class: "w-full" }
        end
        li class: "subtitle"
      end
      if Current.org.trial_baskets? || f.object.trial_baskets_count != Current.org.trial_baskets_count
        f.input :trial_baskets_count
      end
      f.input :salary_basket
    end

    if Current.org.sepa?
      f.inputs t("active_admin.resource.show.billing") + " (SEPA)" do
        f.input :iban,
          placeholder: Billing.iban_placeholder,
          required: false,
          input_html: { value: f.object.iban_formatted }
        f.input :sepa_mandate_id
        f.input :sepa_mandate_signed_on, as: :date_picker, required: false
      end
    end

    if Current.org.annual_fee?
      f.inputs t(".annual_fee") do
        f.input :annual_fee, label: Organization.human_attribute_name(:annual_fee)
      end
    end

    if Current.org.share?
      f.inputs t(".shares") do
        f.input :existing_shares_number
        if member.shares_number.zero? || member.desired_shares_number.positive?
          f.input :desired_shares_number
        end
        f.input :required_shares_number,
          input_html: {
            value: f.object[:required_shares_number],
            placeholder: f.object.default_required_shares_number
          },
          hint: t("formtastic.hints.member.required_shares_number_html")
        f.input :shares_info
      end
    end

    f.inputs t("active_admin.resource.show.notes") do
      f.input :profession
      f.input :come_from, input_html: { rows: 4 }
      f.input :delivery_note
      f.input :food_note, input_html: { rows: 4 }
      f.input :note, input_html: { rows: 4 }, placeholder: false
    end
    f.actions
  end

  permit_params \
    :name, :language, :emails, :phones,
    :address, :city, :zip, :country_code,
    :annual_fee, :salary_basket,
    :billing_email, :trial_baskets_count,
    :different_billing_info,
    :billing_name, :billing_address, :billing_city, :billing_zip,
    :iban, :sepa_mandate_id, :sepa_mandate_signed_on,
    :shares_info, :existing_shares_number,
    :desired_shares_number, :required_shares_number,
    :waiting, :waiting_basket_size_id, :waiting_basket_price_extra,
    :waiting_activity_participations_demanded_annually,
    :waiting_depot_id, :waiting_delivery_cycle_id,
    :waiting_billing_year_division,
    :shop_depot_id,
    :profession, :come_from, :delivery_note, :food_note, :note,
    :contact_sharing,
    waiting_alternative_depot_ids: [],
    members_basket_complements_attributes: [
      :id, :basket_complement_id, :quantity, :_destroy
    ]

  action_item :audits, only: :show, if: -> { authorized?(:read, Audit) && resource.audits.any? } do
    link_to Audit.model_name.human(count: 2), member_audits_path(resource),
      class: "action-item-button"
  end

  action_item :sessions, only: :show, if: -> { authorized?(:read, Session) } do
    link_to Session.model_name.human(count: 2), m_sessions_path(q: { member_id_eq: resource.id }, scope: :all),
      class: "action-item-button"
  end

  action_item :create_membership, only: :show, if: -> { resource.waiting? && authorized?(:create, Membership) && Delivery.next } do
    link_to t(".create_membership"), new_membership_path(member_id: resource.id),
      class: "action-item-button"
  end

  action_item :validate, only: :show, if: -> { authorized?(:validate, resource) } do
    button_to t(".validate"), validate_member_path(resource),
      form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } },
      class: "action-item-button"
  end
  action_item :wait, only: :show, if: -> { authorized?(:wait, resource) } do
    button_to t(".wait"), wait_member_path(resource),
      form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } },
      class: "action-item-button"
  end
  action_item :deactivate, only: :show, if: -> { authorized?(:deactivate, resource) } do
    button_to t(".deactivate"), deactivate_member_path(resource),
      form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } },
      class: "action-item-button"
  end

  action_item :become, only: :show do
    link_to become_member_path(resource), class: "action-item-button", data: { turbo: false } do
      icon("arrow-right-end-on-rectangle", class: "size-4 me-1") + t(".become_member")
    end
  end

  member_action :validate, method: :post do
    resource.validate!(current_admin)
    redirect_to member_path(resource)
  end

  member_action :deactivate, method: :post do
    resource.deactivate!
    redirect_to member_path(resource)
  end

  member_action :wait, method: :post do
    resource.wait!
    redirect_to member_path(resource)
  end

  member_action :become do
    session = Session.create!(
      admin_email: current_admin.email,
      member: resource,
      request: request)
    redirect_to members_session_url(
      session.token,
      subdomain: Current.org.members_subdomain,
      locale: I18n.locale),
      allow_other_host: true
  end

  member_action :recurring_billing, method: :post do
    if invoice = Billing::Invoicer.force_invoice!(resource)
      redirect_to invoice
    else
      redirect_back fallback_location: resource
    end
  end

  member_action :force_share_billing, method: :post do
    if invoice = Billing::InvoicerShare.invoice(resource)
      redirect_to invoice
    else
      redirect_back fallback_location: resource
    end
  end

  controller do
    include TranslatedCSVFilename

    def apply_sorting(chain)
      params[:order] ||= "members.waiting_started_at_asc" if params[:scope] == "waiting"
      super
    end

    def scoped_collection
      collection = Member.all
      if request.format.csv?
        collection = collection.includes(
          :waiting_basket_size,
          :waiting_depot,
          :waiting_delivery_cycle,
          :waiting_basket_complements)
      end
      collection
    end

    def create_resource(object)
      run_create_callbacks object do
        save_resource(object)
        object.validate!(current_admin, skip_email: true) if object.valid?
      end
    end
  end

  order_by("name") do |clause|
    config
      .resource_class
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.sort_order = "name_asc"
end
