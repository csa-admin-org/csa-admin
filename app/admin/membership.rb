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

  filter :member,
    as: :select,
    collection: -> { Member.joins(:memberships).order(:name).distinct }
  filter :basket_size, as: :select, collection: -> { BasketSize.all }
  filter :season,
    as: :select,
    collection: -> { seasons_filter_collection },
    if: proc { Current.acp.seasons? }
  filter :basket_complements,
    as: :select,
    collection: -> { BasketComplement.all },
    if: :any_basket_complements?
  filter :depot, as: :select, collection: -> { Depot.all }
  filter :renewal_state,
    as: :select,
    collection: -> { renewal_states_collection }
  filter :started_on
  filter :ended_on
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  includes :member
  index do
    column :member, sortable: 'members.name'
    column :started_on, ->(m) { l m.started_on, format: :number }
    column :ended_on, ->(m) { l m.ended_on, format: :number }
    if Current.acp.feature?('activity')
      column activities_human_name,
        ->(m) { auto_link m, "#{m.activity_participations_accepted} / #{m.activity_participations_demanded}" },
        sortable: 'activity_participations_demanded', class: 'col-activity_participations_demanded'
    end
    column :baskets_count,
      ->(m) { auto_link m, "#{m.delivered_baskets_count} / #{m.baskets_count}" }
    actions
  end

  sidebar :renewal, only: :index do
    renewal = MembershipsRenewal.new
    to_renew_link = link_to(
      renewal.to_renew.count,
      collection_path(scope: :ongoing, q: { renew_eq: true, during_year: Current.acp.current_fiscal_year.year }))
    renewable_count = renewal.renewable.count
    if renewable_count.positive?
      renewed_count = renewal.renewed.count
      if renewed_count.positive?
        span do
          t('.partially_renewed',
            count: renewed_count,
            count_link: to_renew_link,
            year: Current.acp.current_fiscal_year).html_safe
        end
      else
        span do
          t('.none_renewed',
            count: renewable_count,
            count_link: to_renew_link,
            year: Current.acp.current_fiscal_year).html_safe
        end
      end
      opened_count = renewal.opened.count
      if opened_count.positive?
        div class: 'top-spacing' do
          t('.opened', count: opened_count)
        end
      end
      div class: 'top-spacing' do
        if !Delivery.any_next_year?
          span do
            t('.no_next_year_deliveries',
              fiscal_year: renewal.next_fy,
              new_delivery_path: new_delivery_path).html_safe
          end
        elsif renewal.renewing?
          span { t('.renewing') }
        elsif renewal.opening?
          span { t('.opening') }
        else
          if Current.acp.feature_flag?(:open_renewal)
            openable_count = renewal.openable.count
            if openable_count.positive?
              div do
                link_to t('.open_renewal_all_action', count: openable_count), open_renewal_all_memberships_path,
                  data: { confirm: t('.confirm'), disable_with: t('.opening') },
                  class: 'clear_filters_btn full-width',
                  method: :post
              end
            end
          end
          div class: 'top-small-spacing' do
            link_to t('.renew_all_action', count: renewable_count), renew_all_memberships_path,
              data: { confirm: t('.confirm'), disable_with: t('.renewing') },
              class: 'clear_filters_btn full-width',
              method: :post
          end
        end
      end
    elsif renewal.renewed.any?
      span do
        t('.all_renewed',
          count: renewal.renewed.count,
          count_link: to_renew_link,
          year: Current.acp.current_fiscal_year).html_safe
      end
    else
      span { t('.no_renewals') }
    end
  end

  collection_action :renew_all, method: :post do
    MembershipsRenewal.new.renew_all!
    redirect_to collection_path, notice: t('active_admin.flash.renew_notice')
  rescue MembershipsRenewal::MissingDeliveriesError
    redirect_to collection_path,
      alert: t('active_admin.flash.renew_missing_deliveries_alert', next_year: MembershipsRenewal.new.next_fy)
  end

  collection_action :open_renewal_all, method: :post do
    MembershipsRenewal.new.open_all!
    redirect_to collection_path, notice: t('active_admin.flash.open_renewals_notice')
  rescue MembershipsRenewal::MissingDeliveriesError
    redirect_to collection_path,
      alert: t('active_admin.flash.renew_missing_deliveries_alert', next_year: MembershipsRenewal.new.next_fy)
  end

  csv do
    column(:id)
    column(:name) { |m| m.member.name }
    column(:emails) { |m| m.member.emails_array.join(', ') }
    column(:phones) { |m| m.member.phones_array.map(&:phony_formatted).join(', ') }
    column(:note) { |m| m.member.note }
    column(:basket_size) { |m| basket_size_description(m, text_only: true) }
    if Current.acp.seasons?
      column(:seasons) { |m| m.seasons.map { |s| I18n.t "season.#{s}" }.join(', ') }
    end
    if BasketComplement.any?
      column(:basket_complements) { |m|
        basket_complements_description(m.memberships_basket_complements.includes(:basket_complement),
          text_only: true)
      }
    end
    column(:depot) { |m| m.depot&.name }
    if Current.acp.feature?('activity')
      column(activity_scoped_attribute(:activity_participations_demanded), &:activity_participations_demanded)
      column(activity_scoped_attribute(:missing_activity_participations), &:missing_activity_participations)
    end
    column(:started_on)
    column(:ended_on)
    column(:renewal_state) { |m| I18n.t("active_admin.status_tag.#{m.renewal_state}") }
    column(:renewed_at)
    column(:renewal_note)
    if Current.acp.ragedevert?
      column(:basket_price_extra) { |m| number_to_currency(m.basket_price_extra) }
    end
    column(:price) { |m| number_to_currency(m.price) }
    column(:invoices_amount) { |m| number_to_currency(m.invoices_amount) }
    column(:missing_invoices_amount) { |m| number_to_currency(m.missing_invoices_amount) }
  end

  show do |m|
    columns do
      column do
        next_delivery = Delivery.next
        panel "#{m.baskets_count} #{Basket.model_name.human(count: m.baskets_count)}" do
          table_for(m.baskets.includes(
            :delivery,
            :basket_size,
            :depot,
            :complements,
            baskets_basket_complements: :basket_complement
          ),
            row_class: ->(b) { 'next' if b.delivery == next_delivery },
            class: 'table-baskets'
          ) do
            column(:delivery) { |b| b.delivery.display_name(format: :number) }
            column(:description)
            column(:depot)
            column(class: 'col-status') { |b|
              status_tag(:trial) if b.trial?
              status_tag(:absent) if b.absent?
            }
            column(class: 'col-actions') { |b|
              link_to t('.edit'), edit_basket_path(b), class: 'edit_link'
            }
          end
        end
      end

      column do
        attributes_table do
          row :id
          row :member
          row(:started_on) { l m.started_on }
          row(:ended_on) { l m.ended_on }
        end

        if Date.current > m.started_on
          attributes_table title: Membership.human_attribute_name(:renew) do
            row(:status) { status_tag(m.renewal_state) }
            if m.renewed?
              row(:renewed_at) { l m.renewed_at.to_date }
              row(:renewed_membership)
              row :renewal_note
            elsif m.canceled?
              row :renewal_note
              if m.ended_on == Current.fiscal_year.end_of_year
                div class: 'buttons-inline' do
                  div class: 'button-inline' do
                    link_to t('.enable_renewal'), enable_renewal_membership_path(m),
                      data: { confirm: t('.confirm') },
                      class: 'clear_filters_btn',
                      method: :post
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
                div class: 'button-inline' do
                  link_to t('.renew'), renew_membership_path(m),
                    data: { confirm: t('.confirm') },
                    class: 'clear_filters_btn',
                    method: :post
                end
                div class: 'button-inline' do
                  link_to t('.cancel_renewal'), cancel_membership_path(m),
                    data: { confirm: t('.confirm') },
                    class: 'clear_filters_btn',
                    method: :post
                end
              end
            else
              div class: 'buttons-inline' do
                if Delivery.any_next_year?
                  if Current.acp.feature_flag?(:open_renewal)
                    div class: 'button-inline' do
                      link_to t('.open_renewal'), open_renewal_membership_path(m),
                        data: { confirm: t('.confirm') },
                        disabled: !Delivery.any_next_year?,
                        class: 'clear_filters_btn',
                        method: :post
                    end
                  end
                  div class: 'button-inline' do
                    link_to t('.renew'), renew_membership_path(m),
                      data: { confirm: t('.confirm') },
                      disabled: !Delivery.any_next_year?,
                      class: 'clear_filters_btn',
                      method: :post
                  end
                end
                div class: 'button-inline' do
                  link_to t('.cancel_renewal'), cancel_membership_path(m),
                    data: { confirm: t('.confirm') },
                    class: 'clear_filters_btn',
                    method: :post
                end
              end
            end
          end
        end

        attributes_table title: Membership.human_attribute_name(:description) do
          row(:basket_size) { basket_size_description(m) }
          row :depot
          if BasketComplement.any?
            row(:memberships_basket_complements) {
              basket_complements_description(
                m.memberships_basket_complements.includes(:basket_complement))
            }
          end
        end

        if Current.acp.feature?('activity')
          attributes_table title: activities_human_name do
            row(:activity_participations_demanded) { m.activity_participations_demanded }
            row(:activity_participations_coming) {
              link_to(
                m.member.activity_participations.coming.during_year(m.fiscal_year).sum(:participants_count),
                activity_participations_path(scope: :coming, q: {
                  member_id_eq: resource.member_id,
                  activity_date_gteq_datetime: resource.fiscal_year.beginning_of_year,
                  activity_date_lteq_datetime: resource.fiscal_year.end_of_year
                }))
            }
            row(:activity_participations_pending) {
              link_to(
                m.member.activity_participations.pending.during_year(m.fiscal_year).sum(:participants_count),
                activity_participations_path(scope: :pending, q: {
                  member_id_eq: resource.member_id,
                  activity_date_gteq_datetime: resource.fiscal_year.beginning_of_year,
                  activity_date_lteq_datetime: resource.fiscal_year.end_of_year
                }))
            }
            row(:activity_participations_validated) {
              link_to(
                m.member.activity_participations.validated.during_year(m.fiscal_year).sum(:participants_count),
                activity_participations_path(scope: :validated, q: {
                  member_id_eq: resource.member_id,
                  activity_date_gteq_datetime: resource.fiscal_year.beginning_of_year,
                  activity_date_lteq_datetime: resource.fiscal_year.end_of_year
                }))
            }
            row(:activity_participations_rejected) {
              link_to(
                m.member.activity_participations.rejected.during_year(m.fiscal_year).sum(:participants_count),
                activity_participations_path(scope: :rejected, q: {
                  member_id_eq: resource.member_id,
                  activity_date_gteq_datetime: resource.fiscal_year.beginning_of_year,
                  activity_date_lteq_datetime: resource.fiscal_year.end_of_year
                }))
            }
            row(:activity_participations_paid) {
              link_to(
                m.member.invoices.not_canceled.activity_participation_type.during_year(m.fiscal_year).sum(:paid_missing_activity_participations),
                invoices_path(scope: :all, q: {
                  member_id_eq: resource.member_id,
                  object_type_eq: 'ActivityParticipation',
                  date_gteq: resource.fiscal_year.beginning_of_year,
                  date_lteq: resource.fiscal_year.end_of_year
                }))
            }
          end
        end

        attributes_table(
          title: link_to(
            t('.billing'),
            invoices_path(scope: :all, q: {
              member_id_eq: resource.member_id,
              object_type_eq: 'Membership',
              date_gteq: resource.fiscal_year.beginning_of_year,
              date_lteq: resource.fiscal_year.end_of_year
            }))
          ) do
          if m.member.salary_basket?
            em t('.salary_basket')
          elsif m.baskets_count.zero?
            em t('.no_baskets')
          else
            row(:basket_sizes_price) {
              display_price_description(m.basket_sizes_price, basket_sizes_price_info(m, m.baskets))
            }
            row(:baskets_annual_price_change) {
              number_to_currency(m.baskets_annual_price_change)
            }
            if m.basket_complements.any?
              row(:basket_complements_price) {
                display_price_description(
                  m.basket_complements_price,
                  membership_basket_complements_price_info(m))
              }
              row(:basket_complements_annual_price_change) {
                number_to_currency(m.basket_complements_annual_price_change)
              }
            end
            row(:depots_price) {
              display_price_description(m.depots_price, depots_price_info(m.baskets))
            }
            if Current.acp.feature?('activity')
              row(activity_scoped_attribute(:activity_participations_annual_price_change)) { number_to_currency(m.activity_participations_annual_price_change) }
            end
            row(:price) { number_to_currency(m.price) }
            row(:invoices_amount) { number_to_currency(m.invoices_amount) }
            row(:missing_invoices_amount) { number_to_currency(m.missing_invoices_amount) }
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
      f.input :started_on, as: :datepicker
      f.input :ended_on, as: :datepicker
    end

    if Current.acp.feature?('activity') && !resource.new_record?
      f.inputs activities_human_name do
        f.input :activity_participations_demanded_annualy,
          label: "#{activities_human_name} (#{t('.full_year')})",
          hint: true
        f.input :activity_participations_annual_price_change, label: true, hint: true
      end
    end

    f.inputs t('.basket_and_depot') do
      unless resource.new_record?
        em t('.membership_edit_warning')
      end
      f.input :basket_size, prompt: true, input_html: { class: 'js-reset_price' }
      f.input :basket_price, hint: true, required: false
      if Current.acp.ragedevert?
        f.input :basket_price_extra, required: true
      end
      f.input :baskets_annual_price_change, hint: true
      f.input :basket_quantity
      f.input :depot, prompt: true, input_html: { class: 'js-reset_price' }
      f.input :depot_price, hint: true, required: false
      if Current.acp.seasons?
        f.input :seasons,
          as: :check_boxes,
          collection: seasons_collection,
          hint: true
      end

      if BasketComplement.any?
        complements = BasketComplement.all
        f.has_many :memberships_basket_complements, allow_destroy: true do |ff|
          ff.input :basket_complement,
            collection: complements,
            prompt: true,
            input_html: { class: 'js-reset_price' }
          ff.input :price, hint: true, required: false
          ff.input :quantity
          if Current.acp.seasons?
            ff.input :seasons,
              as: :check_boxes,
              collection: seasons_collection,
              hint: true
          end
        end
        f.input :basket_complements_annual_price_change, hint: true
      end
    end
    f.actions
  end

  permit_params \
    :member_id,
    :basket_size_id, :basket_price, :basket_price_extra, :basket_quantity, :baskets_annual_price_change,
    :depot_id, :depot_price,
    :started_on, :ended_on, :renew,
    :activity_participations_annual_price_change, :activity_participations_demanded_annualy,
    :basket_complements_annual_price_change,
    seasons: [],
    memberships_basket_complements_attributes: [
      :id, :basket_complement_id,
      :price, :quantity,
      :_destroy,
      seasons: []
    ]

  action_item :trigger_recurring_billing, only: :show, if: -> {
    authorized?(:trigger_recurring_billing, resource) && RecurringBilling.new(resource.member).needed?
  } do
    link_to t('.trigger_recurring_billing'), trigger_recurring_billing_membership_path(resource),
      method: :post,
      title: t('.trigger_recurring_billing_title')
  end

  member_action :trigger_recurring_billing, method: :post do
    RecurringBilling.invoice(resource.member)
    redirect_to invoices_path(q: { member_id_eq: resource.member_id, date_gteq: resource.fiscal_year.beginning_of_year, date_lteq: resource.fiscal_year.end_of_year }, scope: :all, order: :date_asc)
  end

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
    membership.member_id ||= params[:member_id]
    membership.basket_size_id ||= params[:basket_size_id]
    if params[:basket_price_extra]
      membership.basket_price_extra = params[:basket_price_extra]
    end
    membership.depot_id ||= params[:depot_id]
    params[:subscribed_basket_complement_ids]&.each do |id|
      membership.memberships_basket_complements.build(basket_complement_id: id)
    end
    if fy_range = Delivery.next&.fy_range
      membership.started_on ||= params[:started_on] || [Date.current, fy_range.min].max
      membership.ended_on ||= fy_range.max
    end
  end

  before_save do |membership|
    membership.skip_touch = true
  end

  controller do
    include TranslatedCSVFilename

    def apply_filtering(chain)
      super(chain).distinct
    end

    def apply_sorting(chain)
      super(chain).joins(:member).order('members.name')
    end
  end

  config.per_page = 30
  config.sort_order = 'started_on_desc'
end
