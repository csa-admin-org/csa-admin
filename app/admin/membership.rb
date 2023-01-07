ActiveAdmin.register Membership do
  menu priority: 3

  breadcrumb do
    if params[:action] == 'new'
      [link_to(Membership.model_name.human(count: 2), memberships_path)]
    elsif params['action'] != 'index'
      links = [
        link_to(Member.model_name.human(count: 2), members_path),
        auto_link(membership.member),
        link_to(
          Membership.model_name.human(count: 2),
          memberships_path(q: { member_id_eq: membership.member_id }, scope: :all))
      ]
      if params['action'].in? %W[edit]
        links << auto_link(membership)
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
  filter :basket_size, as: :select, collection: -> { BasketSize.all }
  filter :basket_complements,
    as: :select,
    collection: -> { BasketComplement.all },
    if: :any_basket_complements?
  filter :depot, as: :select, collection: -> { Depot.all }
  filter :deliveries_cycle, as: :select
  filter :renewal_state,
    as: :select,
    collection: -> { renewal_states_collection }
  filter :started_on
  filter :ended_on
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :basket_price_extra,
    label: proc { Current.acp.basket_price_extra_title },
    if: proc { Current.acp.feature?('basket_price_extra') }
  filter :activity_participations_accepted,
    label: proc { t_activity('active_admin.resource.index.activity_participations_accepted') },
    if: proc { Current.acp.feature?('activity') }
  filter :activity_participations_demanded,
    label: proc { t_activity('active_admin.resource.index.activity_participations_demanded') },
    if: proc { Current.acp.feature?('activity') }

  includes :member, :baskets, :deliveries_cycle
  index do
    column :id, ->(m) { auto_link m, m.id }
    column :member, sortable: 'members.name'
    column :started_on, ->(m) { auto_link m, l(m.started_on, format: :number) }
    column :ended_on, ->(m) { auto_link m, l(m.ended_on, format: :number) }
    if Current.acp.feature?('activity')
      column activities_human_name, ->(m) {
        link_to(
          "#{m.activity_participations_accepted} / #{m.activity_participations_demanded}",
          activity_participations_path(q: {
            member_id_eq: m.member_id,
            during_year: m.fiscal_year,
          }, scope: 'all'))
      }, sortable: 'activity_participations_demanded', class: 'col-activity_participations_demanded'
    end
    column :baskets_count,
      ->(m) { auto_link m, "#{m.delivered_baskets_count} / #{m.baskets_count}" }
    actions defaults: false, class: 'col-actions-2' do |resource|
      localizer = ActiveAdmin::Localizers.resource(active_admin_config)
      if authorized?(ActiveAdmin::Auth::READ, resource)
        item localizer.t(:view), resource_path(resource), class: "view_link member_link", title: localizer.t(:view)
      end
      if authorized?(ActiveAdmin::Auth::UPDATE, resource)
        item localizer.t(:edit), edit_resource_path(resource), class: "edit_link member_link", title: localizer.t(:edit)
      end
    end
  end

  sidebar :renewal, only: :index do
    div class: 'actions' do
      handbook_icon_link('membership_renewal')
    end

    renewal = MembershipsRenewal.new
    if !Delivery.any_next_year?
      div class: 'content' do
        t('.no_next_year_deliveries',
          fiscal_year: renewal.next_fy,
          new_delivery_path: new_delivery_path).html_safe
      end
    else
      div class: 'content' do
        ul do
          li do
            openable_count = renewal.openable.count
            t('.openable_renewals',
              count: openable_count,
              count_link: link_to(
                openable_count,
                collection_path(scope: :all, q: { renewal_state_eq: :renewal_enabled, during_year: Current.acp.current_fiscal_year.year }))
            ).html_safe
          end
          if MailTemplate.active_template(:membership_renewal)
            li do
              renewal_opened_count = renewal.opened.count
              t('.opened_renewals',
                count: renewal_opened_count,
                count_link: link_to(
                  renewal_opened_count,
                  collection_path(scope: :all, q: { renewal_state_eq: :renewal_opened, during_year: Current.acp.current_fiscal_year.year }))
              ).html_safe
            end
          end
          li do
            renewed_count = renewal.renewed.count
            t('.renewed_renewals',
              count: renewed_count,
              count_link: link_to(
                renewed_count,
                collection_path(scope: :all, q: { renewal_state_eq: :renewed, during_year: Current.acp.current_fiscal_year.year }))
            ).html_safe
          end
          li do
            end_of_year = Current.acp.current_fiscal_year.end_of_year
            renewal_canceled_count = Membership.where(renew: false).where(ended_on: end_of_year).count
            t('.canceled_renewals',
              count: renewal_canceled_count,
              count_link: link_to(
                renewal_canceled_count,
                collection_path(scope: :all, q: { renewal_state_eq: :renewal_canceled, during_year: Current.acp.current_fiscal_year.year, ended_on_gteq: end_of_year, ended_on_lteq: end_of_year }))
            ).html_safe
          end
        end
      end
      renewable_count = renewal.renewable.count
      if renewable_count.positive?
        div class: 'content top-spacing' do
          if renewal.renewing?
            span { t('.renewing') }
          elsif renewal.opening?
            span { t('.opening') }
          else
            if authorized?(:open_renewal_all, Membership) && MailTemplate.active_template(:membership_renewal)
              openable_count = renewal.openable.count
              if openable_count.positive?
                div class: 'top-small-spacing' do
                  button_to t('.open_renewal_all_action', count: openable_count), open_renewal_all_memberships_path,
                    form: { data: { controller: 'disable', disable_with_value: t('.opening') } },
                    class: 'full-width'
                end
              end
            end
            if authorized?(:renew_all, Membership)
              div class: 'top-small-spacing' do
                button_to t('.renew_all_action', count: renewable_count), renew_all_memberships_path,
                  form: { data: { controller: 'disable', disable_with_value: t('.renewing') } },
                  class: 'full-width'
              end
            end
          end
        end
      end
    end
  end

  sidebar :basket_price_extra_title, only: :index, if: -> { Current.acp.feature?('basket_price_extra') && params.dig(:q, :during_year) } do
    div class: 'actions' do
      handbook_icon_link('basket_price_extra')
    end

    coll = collection.unscope(:includes, :order).limit(nil)
    all = coll.includes(:baskets, :member)

    div class: 'content' do
      if coll.where('basket_price_extra < 0').any?
        div class: 'total' do
          sum = all.where('basket_price_extra > 0').sum(&:baskets_price_extra)
          span cur(sum), style: 'text-align: right; display: inline-block; width: 100%;'
        end
        div class: 'total' do
          sum = all.where('basket_price_extra < 0').sum(&:baskets_price_extra)
          span cur(sum), style: 'text-align: right; display: inline-block; width: 100%;'
        end
      end
      div class: 'totals' do
        sum = all.sum(&:baskets_price_extra)
        span t('active_admin.sidebars.amount')
        span cur(sum), style: 'float: right; font-weight: bold;'
      end
    end
  end

  collection_action :renew_all, method: :post do
    authorize!(:renew_all, Membership)
    MembershipsRenewal.new.renew_all!
    redirect_to collection_path, notice: t('active_admin.flash.renew_notice')
  rescue MembershipsRenewal::MissingDeliveriesError
    redirect_to collection_path,
      alert: t('active_admin.flash.renew_missing_deliveries_alert', next_year: MembershipsRenewal.new.next_fy)
  end

  collection_action :open_renewal_all, method: :post do
    authorize!(:open_renewal_all, Membership)
    MembershipsRenewal.new.open_all!
    redirect_to collection_path, notice: t('active_admin.flash.open_renewals_notice')
  rescue MembershipsRenewal::MissingDeliveriesError
    redirect_to collection_path,
      alert: t('active_admin.flash.renew_missing_deliveries_alert', next_year: MembershipsRenewal.new.next_fy)
  end

  csv do
    column(:id)
    column(:member_id)
    column(:name) { |m| m.member.name }
    column(:emails) { |m| m.member.emails_array.join(', ') }
    column(:phones) { |m| m.member.phones_array.map { |p| display_phone(p) }.join(', ') }
    column(:note) { |m| m.member.note }
    column(:started_on)
    column(:ended_on)
    column(:baskets_count)
    if Current.acp.trial_basket_count.positive?
      column(:baskets_trial_count) { |m| m.baskets.select(&:trial?).size }
    end
    if Current.acp.feature?('absence')
      column(:baskets_absent_count) { |m| m.baskets.select(&:absent?).size }
    end
    column(:basket_size) { |m| basket_size_description(m, text_only: true, public_name: false) }
    column(:basket_price) { |m| cur(m.basket_price) }
    if Current.acp.feature?('basket_price_extra')
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
    if BasketComplement.any?
      column(:basket_complements) { |m|
        basket_complements_description(m.memberships_basket_complements.includes(:basket_complement),
          text_only: true,
          public_name: false)
      }
    end
    column(:depot) { |m| m.depot.name }
    column(:depot_price) { |m| cur(m.depot_price) }
    column(:deliveries_cycle) { |m| m.deliveries_cycle.name }
    if Current.acp.feature?('activity')
      column(activity_scoped_attribute(:activity_participations_demanded), &:activity_participations_demanded)
      column(activity_scoped_attribute(:activity_participations_accepted), &:activity_participations_accepted)
      column(activity_scoped_attribute(:missing_activity_participations), &:missing_activity_participations)
    end
    column(:renewal_state) { |m| t("active_admin.status_tag.#{m.renewal_state}") }
    column(:renewed_at)
    column(:renewal_note)
    column(activity_scoped_attribute(:activity_participations_annual_price_change)) { |m| cur(m.activity_participations_annual_price_change) }
    column(:baskets_annual_price_change) { |m| cur(m.baskets_annual_price_change) }
    if BasketComplement.any?
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
        panel "#{m.baskets_count} #{Basket.model_name.human(count: m.baskets_count)}" do
          table_for(m.baskets.preload(
            :membership,
            :delivery,
            :basket_size,
            :depot,
            :complements,
            baskets_basket_complements: :basket_complement
          ),
            row_class: ->(b) { 'next' if b == next_basket },
            class: 'table-baskets'
          ) do
            column(:delivery) { |b| link_to b.delivery.display_name(format: :number), b.delivery }
            column(:description)
            column(:depot)
            if m.baskets.trial.any? || m.baskets.absent.any?
              column(class: 'col-status') { |b|
                status_tag(:trial) if b.trial?
                status_tag(:absent) if b.absent?
              }
            end
            column(class: 'col-actions-1') { |b|
              if authorized?(:update, b)
                link_to t('.edit'), edit_basket_path(b), class: 'edit_link'
              end
            }
          end
        end
      end

      column do
        attributes_table do
          row :id
          row :member
          row(:period) { [l(m.started_on),l(m.ended_on)].join(' - ') }
          row(:fiscal_year)
          row(:created_at) { l m.created_at, format: :long }
        end

        attributes_table title: t('.config') do
          row(:basket_size) { basket_size_description(m, text_only: true, public_name: false) }
          if BasketComplement.any?
            row(:memberships_basket_complements) {
              basket_complements_description(
                m.memberships_basket_complements.includes(:basket_complement), text_only: true, public_name: false)
              }
            end
          row :depot
          row :deliveries_cycle
        end

        if Current.fiscal_year >= m.fiscal_year
          attributes_table title: Membership.human_attribute_name(:renew) do
            div class: 'actions' do
              handbook_icon_link('membership_renewal')
            end

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
              if m.ended_on == Current.fiscal_year.end_of_year && authorized?(:enable_renewal, m)
                div class: 'buttons-inline' do
                  div class: 'button-inline' do
                    button_to t('.enable_renewal'), enable_renewal_membership_path(m),
                      form: {
                        data: { controller: 'disable', disable_with_value: t('formtastic.processing') },
                      },
                      data: { confirm: t('.confirm') }
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
              div class: 'buttons-inline' do
                if authorized?(:renew, m)
                  div class: 'button-inline' do
                    button_to t('.renew'), renew_membership_path(m),
                      form: {
                        data: { controller: 'disable', disable_with_value: t('formtastic.processing') },
                      },
                      data: { confirm: t('.confirm') }
                  end
                end
                if authorized?(:cancel, m)
                  div class: 'button-inline' do
                    button_to t('.cancel_renewal'), cancel_membership_path(m),
                      form: {
                        data: { controller: 'disable', disable_with_value: t('formtastic.processing') },
                      },
                      data: { confirm: t('.confirm') }
                  end
                end
              end
            else
              div class: 'buttons-inline' do
                if Delivery.any_next_year?
                  if authorized?(:open_renewal, m) && MailTemplate.active_template(:membership_renewal)
                    div class: 'button-inline' do
                      button_to t('.open_renewal'), open_renewal_membership_path(m),
                        form: {
                          data: { controller: 'disable', disable_with_value: t('formtastic.processing') },
                        },
                        data: { confirm: t('.confirm') }
                    end
                  end
                  if authorized?(:renew, m)
                    div class: 'button-inline' do
                      button_to t('.renew'), renew_membership_path(m),
                        form: {
                          data: { controller: 'disable', disable_with_value: t('formtastic.processing') },
                        },
                        data: { confirm: t('.confirm') }
                      end
                  end
                end
                if authorized?(:cancel, m)
                  div class: 'button-inline' do
                    button_to t('.cancel_renewal'), cancel_membership_path(m),
                      form: {
                        data: { controller: 'disable', disable_with_value: t('formtastic.processing') },
                      },
                      data: { confirm: t('.confirm') }
                  end
                end
              end
            end
          end
        end

        if Current.acp.feature?('activity')
          attributes_table title: activities_human_name do
            row(:activity_participations_demanded) { m.activity_participations_demanded }
            row(:activity_participations_future) {
              link_to(
                m.member.activity_participations.future.during_year(m.fiscal_year).sum(:participants_count),
                activity_participations_path(scope: :future, q: {
                  member_id_eq: resource.member_id,
                  during_year: resource.fiscal_year.year
                }))
            }
            row(:activity_participations_pending) {
              link_to(
                m.member.activity_participations.pending.during_year(m.fiscal_year).sum(:participants_count),
                activity_participations_path(scope: :pending, q: {
                  member_id_eq: resource.member_id,
                  during_year: resource.fiscal_year.year
                }))
            }
            row(:activity_participations_validated) {
              link_to(
                m.member.activity_participations.validated.during_year(m.fiscal_year).sum(:participants_count),
                activity_participations_path(scope: :validated, q: {
                  member_id_eq: resource.member_id,
                  during_year: resource.fiscal_year.year
                }))
            }
            row(:activity_participations_rejected) {
              link_to(
                m.member.activity_participations.rejected.during_year(m.fiscal_year).sum(:participants_count),
                activity_participations_path(scope: :rejected, q: {
                  member_id_eq: resource.member_id,
                  during_year: resource.fiscal_year.year
                }))
            }
            row(:activity_participations_paid) {
              link_to(
                m.member.invoices.not_canceled.activity_participation_type.during_year(m.fiscal_year).sum(:paid_missing_activity_participations),
                invoices_path(scope: :all_without_canceled, q: {
                  member_id_eq: resource.member_id,
                  object_type_in: 'ActivityParticipation',
                  during_year: resource.fiscal_year.year
                }))
            }
          end
        end

        attributes_table title: t('.billing') do
          div class: 'actions' do
            handbook_icon_link('billing', anchor: 'abonnements')
          end

          if m.member.salary_basket?
            em t('.salary_basket')
          elsif m.baskets_count.zero?
            em t('.no_baskets')
          else
            row(:basket_sizes_price) {
              display_price_description(m.basket_sizes_price, basket_sizes_price_info(m, m.baskets))
            }
            if Current.acp.feature?('basket_price_extra')
              row(:basket_price_extra_title) {
                display_price_description(m.baskets_price_extra, baskets_price_extra_info(m.baskets))
              }
            end
            row(:baskets_annual_price_change) {
              cur(m.baskets_annual_price_change)
            }
            if m.basket_complements.any?
              row(:basket_complements_price) {
                display_price_description(
                  m.basket_complements_price,
                  membership_basket_complements_price_info(m))
              }
              row(:basket_complements_annual_price_change) {
                cur(m.basket_complements_annual_price_change)
              }
            end
            row(:depots_price) {
              display_price_description(m.depots_price, depots_price_info(m.baskets))
            }
            if Current.acp.feature?('activity')
              row(activity_scoped_attribute(:activity_participations_annual_price_change)) { cur(m.activity_participations_annual_price_change) }
            end
            row(:price) { cur(m.price) }
            row(:invoices_amount) {
              link_to(
                cur(m.invoices_amount),
                invoices_path(scope: :all_without_canceled, q: {
                  member_id_eq: resource.member_id,
                  object_type_in: 'Membership',
                  during_year: resource.fiscal_year.year
                }))
            }
            row(:missing_invoices_amount) { cur(m.missing_invoices_amount) }
            row(:next_invoice_on) {
              if resource.billable?
                if Current.acp.recurring_billing?
                  invoicer = Billing::Invoicer.new(resource.member, resource)
                  if invoicer.next_date
                    span class: 'next_date' do
                      l(invoicer.next_date, format: :long_medium)
                    end
                    if authorized?(:force_recurring_billing, resource.member) && invoicer.billable?
                      button_to t('.force_recurring_billing'), force_recurring_billing_member_path(resource.member),
                        form: {
                          data: { controller: 'disable', disable_with_value: t('formtastic.processing') },
                          class: 'inline'
                        },
                        data: { confirm: t('.force_recurring_billing_confirm') }
                    end
                  end
                else
                  span class: 'empty' do
                    t('.recurring_billing_disabled')
                  end
                end
              end
            }
          end
        end

        active_admin_comments
      end
    end
  end

  form do |f|
    f.inputs Member.model_name.human do
      f.input :member,
        collection: Member.order(:name).map { |d| [d.name, d.id] },
        prompt: true
    end
    f.inputs Membership.human_attribute_name(:dates) do
      f.input :started_on, as: :date_picker
      f.input :ended_on, as: :date_picker
    end

    if Current.acp.annual_fee? && f.object.canceled?
      f.inputs Membership.human_attribute_name(:renew) do
        f.input :renewal_annual_fee
      end
    end

    if Current.acp.feature?('activity')
      f.inputs activities_human_name do
        f.input :activity_participations_demanded_annualy,
          label: "#{activities_human_name} (#{t('.full_year')})",
          hint: t('formtastic.hints.membership.activity_participations_demanded_annualy_html')
        f.input :activity_participations_annual_price_change,
          label: true,
          hint: true
      end
    end

    f.inputs t('.billing') do
      if Current.acp.feature?('basket_price_extra')
        f.input :basket_price_extra, required: true, label: Current.acp.basket_price_extra_title
      end
      f.input :baskets_annual_price_change, hint: true
      if BasketComplement.any?
        f.input :basket_complements_annual_price_change, hint: true
      end
    end

    h3 t('.config')
    if resource.new_record?
      para t('.membership_configuration_text')
    else
      para t('.membership_configuration_warning_text'), class: 'new_config_from warning'
      f.inputs do
        f.input :new_config_from, as: :date_picker, required: true
      end
    end
    f.inputs [
      Depot.model_name.human(count: 1),
      DeliveriesCycle.model_name.human(count: 1)
    ].to_sentence, 'data-controller' => 'form-reset' do
      f.input :depot,
        prompt: true,
        input_html: {
          data: {
            controller: 'form-select-options',
            action: 'form-select-options#update form-reset#reset',
            form_select_options_target_param: 'membership_deliveries_cycle_id'
          }
        },
        collection: Depot.all.map { |d|
          [
            d.name, d.id,
            data: {
              form_select_options_values_param: d.deliveries_cycle_ids.join(',')
            }
          ]
        }
      f.input :depot_price,
        hint: true,
        required: false,
        input_html: { data: { form_reset_target: 'input' } }
      f.input :deliveries_cycle,
        as: :select,
        collection: deliveries_cycles_collection,
        disabled: f.object.depot ? (DeliveriesCycle.pluck(:id) - f.object.depot.deliveries_cycle_ids) : [],
        prompt: true
    end
    f.inputs [
      Basket.model_name.human(count: 1),
      BasketComplement.any? ? Membership.human_attribute_name(:memberships_basket_complements) : nil
    ].compact.to_sentence, 'data-controller' => 'form-reset' do
      f.input :basket_size,
        prompt: true,
        input_html: { data: { action: 'form-reset#reset' } }
      f.input :basket_price,
        hint: true,
        required: false,
        input_html: { data: { form_reset_target: 'input' } }
      f.input :basket_quantity

      if BasketComplement.any?
        complements = BasketComplement.all
        f.has_many :memberships_basket_complements, allow_destroy: true do |ff|
          ff.inputs class: 'blank', 'data-controller' => 'form-reset' do
            ff.input :basket_complement,
              collection: complements,
              prompt: true,
              input_html: { data: { action: 'form-reset#reset' } }
            ff.input :price,
              hint: true,
              required: false,
              input_html: { data: { form_reset_target: 'input' } }
            ff.input :quantity
            ff.input :deliveries_cycle,
              as: :select,
              collection: deliveries_cycles_collection,
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
    :depot_id, :depot_price, :deliveries_cycle_id,
    :started_on, :ended_on, :renew, :renewal_annual_fee,
    :activity_participations_annual_price_change, :activity_participations_demanded_annualy,
    :basket_complements_annual_price_change,
    :new_config_from,
    memberships_basket_complements_attributes: [
      :id, :basket_complement_id,
      :price, :quantity,
      :deliveries_cycle_id,
      :_destroy
    ]

  member_action :open_renewal, method: :post do
    resource.open_renewal!
    redirect_to resource
  end

  member_action :enable_renewal, method: :post do
    resource.enable_renewal!
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
    if member = Member.find_by(id: params[:member_id])
      membership.member_id ||= member.id
      membership.basket_size_id ||= member.waiting_basket_size&.id
      if member.waiting_basket_price_extra&.positive?
        membership.basket_price_extra = member.waiting_basket_price_extra
      end
      membership.depot_id ||= member.waiting_depot&.id
      membership.deliveries_cycle_id ||= member.waiting_deliveries_cycle&.id
      member.members_basket_complements.each do |mbc|
        membership.memberships_basket_complements.build(
          basket_complement_id: mbc.basket_complement_id,
          quantity: mbc.quantity)
      end
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
      super(chain).joins(:member).order('members.name')
    end
  end

  config.per_page = 50
  config.sort_order = 'started_on_desc'
end
