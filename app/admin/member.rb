ActiveAdmin.register Member do
  menu priority: 2

  scope :all
  scope :pending
  scope :waiting
  scope :active, default: true
  scope :support
  scope :inactive

  filter :id
  filter :with_name, as: :string
  filter :with_address, as: :string
  filter :with_phone, as: :string
  filter :with_email, as: :string
  filter :with_waiting_depots,
    label: -> { Member.human_attribute_name(:waiting_depot) },
    as: :select,
    collection: -> { Depot.visible },
    if: proc { params[:scope].in? ['waiting', nil] }
  filter :city, as: :select, collection: -> {
    Member.pluck(:city).uniq.map(&:presence).compact.sort
  }
  filter :country_code, as: :select, collection: -> {
    country_codes = Member.pluck(:country_code).uniq.map(&:presence).compact.sort
    countries_collection(country_codes)
  }
  filter :billing_year_division,
    as: :select,
    collection: -> { Current.acp.billing_year_divisions.map { |i| [I18n.t("billing.year_division.x#{i}"), i] } }
  filter :salary_basket,
    as: :boolean,
    if: proc { params[:scope].in? ['active', nil] }

  includes next_basket: [:basket_size, :baskets_basket_complements, :depot, :membership]
  index do
    column :id, ->(member) { auto_link member, member.id }
    if params[:scope] == 'waiting'
      @waiting_started_ats ||= Member.waiting.order(:waiting_started_at).pluck(:waiting_started_at)
      column '#', ->(member) {
        @waiting_started_ats.index(member.waiting_started_at) + 1
      }, sortable: :waiting_started_at
    end
    column :name, ->(member) { auto_link member }
    case params[:scope]
    when 'pending', 'waiting'
      column Depot.model_name.human(count: Current.acp.allow_alternative_depots? ? 2 : 1), ->(member) {
        ([member.waiting_depot] + member.waiting_alternative_depots)
          .compact.map(&:name).to_sentence.truncate(50)
      }
    when nil, 'all', 'active'
      column :next_basket, ->(member) {
        if next_basket = member.next_basket
          a href: url_for(member.next_basket.membership) do
            content_tag(:span, [
              next_basket.description,
              next_basket.depot.name
            ].join(' / '))
          end
          status_tag(:trial) if next_basket.trial?
        end
      }
    else
      column :city, ->(member) { member.city? ? "#{member.city} (#{member.zip})" : '–' }
    end
    column :state, ->(member) { status_tag(member.state) }
    actions class: 'col-actions-3'
  end

  csv do
    column(:id)
    column(:name)
    column(:state, &:state_i18n_name)
    column(:emails) { |m| m.emails_array.join(', ') }
    column(:phones) { |m| m.phones_array.map(&:phony_formatted).join(', ') }
    if Current.acp.languages.many?
      column(:language) { |m| t("languages.#{m.language}") }
    end
    column(:address)
    column(:zip)
    column(:city)
    column(:country_code)
    column(:delivery_address)
    column(:delivery_zip)
    column(:delivery_city)
    column(:profession)
    column(:billing_year_division) { |m| t("billing.year_division.x#{m.billing_year_division}") }
    if Current.acp.annual_fee
      column(:annual_fee) { |m| cur(m.annual_fee) }
    end
    if Current.acp.share?
      column(:acp_shares_number)
    end
    column(:salary_basket, &:salary_basket?)
    column(:waiting_started_at)
    column(:waiting_basket_size) { |m| m.waiting_basket_size&.name }
    if Current.acp.feature_flag?(:basket_price_extra)
      column(:waiting_basket_price_extra) { |m| cur(m.waiting_basket_price_extra) }
    end
    if BasketComplement.any?
      column(:waiting_basket_complements) { |m|
        basket_complements_description(
          m.members_basket_complements.includes(:basket_complement),
          text_only: true,
          public_name: false)
      }
    end
    column(:waiting_depot) { |m| m.waiting_depot&.name }
    if Current.acp.allow_alternative_depots?
      column(:waiting_alternative_depot_ids) { |m|
        m.waiting_alternative_depots.map(&:name).to_sentence
      }
    end
    if Current.acp.feature?('contact_sharing')
      column(:contact_sharing)
    end
    column(:food_note)
    column(:note)
    column(:validated_at)
    column(:created_at)
    column(:invoices_amount) { |m| cur m.invoices_amount }
    column(:payments_amount) { |m| cur m.payments_amount }
    column(:balance_amount) { |m| cur m.balance_amount }
  end

  show do |member|
    columns do
      column do
        if next_basket = member.next_basket
          attributes_table title: link_to(Member.human_attribute_name(:next_basket), next_basket.membership) do
            if next_basket.trial?
              row(:state) { status_tag(:trial) }
            end
            row(:basket_size) { basket_size_description(member.next_basket, text_only: true, public_name: false) }
            if BasketComplement.any?
              row(Membership.human_attribute_name(:memberships_basket_complements)) {
                basket_complements_description(member.next_basket.baskets_basket_complements, text_only: true, public_name: false)
              }
            end
            row(:depot) { link_to next_basket.depot.name, next_basket.depot  }
            row(:delivery) { link_to next_basket.delivery.display_name(format: :long), next_basket.delivery }
            if Current.acp.feature_flag?('shop')
              shop_order = next_basket.delivery.shop_orders.find_by(member_id: member.id)
              row(I18n.t('shop.title')) { auto_link shop_order }
            end
            row(Membership.model_name.human) { link_to "##{next_basket.membership.id} (#{next_basket.membership.fiscal_year})", next_basket.membership }
          end
        end

        if member.pending? || member.waiting?
          attributes_table title: t('.waiting_membership') do
            row(:basket_size) { member.waiting_basket_size&.name }
            if Current.acp.feature_flag?(:basket_price_extra)
              row(:basket_price_extra) { cur(member.waiting_basket_price_extra) }
            end
            if BasketComplement.any?
              row(Membership.human_attribute_name(:memberships_basket_complements)) {
                basket_complements_description(
                  member.members_basket_complements.includes(:basket_complement), text_only: true, public_name: false)
              }
            end
            row(:depot) { member.waiting_depot&.name }
            if Current.acp.allow_alternative_depots?
              row(:waiting_alternative_depot_ids) {
                member.waiting_alternative_depots.map(&:name).to_sentence
              }
            end
            if member.waiting?
              row :waiting_started_at
            end
          end
        end

        all_memberships_path = memberships_path(q: { member_id_eq: member.id }, scope: :all)
        panel link_to(Membership.model_name.human(count: 2), all_memberships_path) do
          memberships = member.memberships.order(started_on: :desc)
          memberships_count = memberships.count
          if memberships_count.zero?
            em t('.no_memberships')
          else
            table_for(memberships.limit(3), class: 'table-memberships') do
              column(:period) { |m| auto_link m, membership_short_period(m) }
              if Current.acp.feature?('activity')
                column(activities_human_name, class: 'col-activity_participations_demanded') { |m|
                  auto_link m, "#{m.activity_participations_accepted} / #{m.activity_participations_demanded}"
                }
              end
              column(:baskets_count) { |m|
                auto_link m, "#{m.delivered_baskets_count} / #{m.baskets_count}"
              }
            end
            if memberships_count > 3
              em link_to(t('.show_more'), all_memberships_path), class: 'show_more'
            end
          end
        end

        if Current.acp.feature?('activity')
          all_activity_participations_path =
            activity_participations_path(q: { member_id_eq: member.id }, scope: :all)
          panel link_to(activities_human_name, all_activity_participations_path) do
            activity_participations =
              member.activity_participations.includes(:activity)
                .order('activities.date DESC, activities.start_time DESC')
            activity_participations_count = activity_participations.count
            if activity_participations_count.zero?
              em t_activity('.no_activities')
            else
              table_for(activity_participations.limit(6), class: 'table-activity_participations') do
                column(Activity.model_name.human) { |ap|
                  auto_link ap, ap.activity.name
                }
                column(:participants_count)
                column(:state) { |ap| status_tag(ap.state) }
              end
              if activity_participations_count > 6
                em link_to(t('.show_more'), all_activity_participations_path), class: 'show_more'
              end
            end
          end
        end

        all_invoices_path = invoices_path(q: { member_id_eq: member.id }, scope: :all)
        panel link_to(Invoice.model_name.human(count: 2), all_invoices_path) do
          invoices = member.invoices.includes(pdf_file_attachment: :blob).order(date: :desc)
          invoices_count = invoices.count
          if invoices_count.zero?
            em t('.no_invoices')
          else
            table_for(invoices.limit(6), class: 'table-invoices') do
              column(:id) { |i| auto_link i, i.id }
              column(:date) { |i| l(i.date, format: :number) }
              column(:amount) { |i| cur(i.amount) }
              column(:paid_amount) { |i| cur(i.paid_amount) }
              column(:overdue_notices_count)
              column(:status) { |i| status_tag i.state }
              column(class: 'col-actions') { |i| link_to_invoice_pdf(i) }
            end
            if invoices_count > 6
              em link_to(t('.show_more'), all_invoices_path), class: 'show_more'
            end
          end
        end

        all_payments_path = payments_path(q: { member_id_eq: member.id }, scope: :all)
        panel link_to(Payment.model_name.human(count: 2), all_payments_path) do
          payments = member.payments.includes(:invoice).reorder(date: :desc)
          payments_count = payments.count
          if payments_count.zero?
            em t('.no_payments')
          else
            table_for(payments.limit(6), class: 'table-payments') do
              column(:id) { |p| auto_link p, p.id }
              column(:date) { |p| l(p.date, format: :number) }
              column(:invoice_id) { |p| p.invoice_id ? auto_link(p.invoice, p.invoice_id) : '–' }
              column(:amount) { |p| cur(p.amount) }
              column(:type) { |p| status_tag p.type }
            end
            if payments_count > 6
              em link_to(t('.show_more'), all_payments_path), class: 'show_more'
            end
          end
        end

        if Current.acp.feature?('absence')
          all_absences_path = absences_path(q: { member_id_eq: member.id }, scope: :all)
          panel link_to(Absence.model_name.human(count: 2), all_absences_path) do
            absences = member.absences.order(started_on: :desc)
            absences_count = absences.count
            if absences_count.zero?
              em t('.no_absences')
            else
              table_for(absences.limit(3), class: 'table-absences') do
                column(:started_on) { |a| auto_link a, l(a.started_on) }
                column(:ended_on) { |a| auto_link a, l(a.ended_on) }
              end
              if absences_count > 3
                em link_to(t('.show_more'), all_absences_path), class: 'show_more'
              end
            end
          end
        end
      end

      column do
        attributes_table do
          row(:id) {
            span { member.id.to_s }
            if authorized?(:become, resource)
              link_to(t('.become_member'), become_member_path(resource), class: 'button')
            end
          }
          row(:status) { status_tag member.state }
          if Current.acp.languages.many?
            row(:language) { t("languages.#{member.language}") }
          end
          row(:created_at) { l member.created_at }
          row(:validated_at) { member.validated_at ? l(member.validated_at) : nil }
          row :validator
        end
        attributes_table title: Member.human_attribute_name(:contact) do
          row :name
          row(Member.human_attribute_name(:address)) { member.display_address }
          unless member.same_delivery_address?
            row(Member.human_attribute_name(:delivery_address)) { member.display_delivery_address }
          end
          row(:emails) { display_emails_with_link(self, member.emails_array) }
          row(:phones) { display_phones_with_link(self, member.phones_array) }
          if Current.acp.feature?('contact_sharing')
            row(:contact_sharing) { status_tag(member.contact_sharing) }
          end
        end
        attributes_table title: t('.billing') do
          row(:billing_year_division) { t("billing.year_division.x#{member.billing_year_division}") }
          row(:salary_basket) { status_tag(member.salary_basket) }
          if Current.acp.annual_fee
            row(:annual_fee) { cur member.annual_fee }
          end
          if Current.acp.share?
            row(:acp_shares_number) { display_acp_shares_number(member) }
            row(:acp_shares_info) { member.acp_shares_info }
          end
          row(:invoices_amount) {
            link_to(
              cur(member.invoices_amount),
              invoices_path(q: { member_id_eq: member.id }, scope: :all))
          }
          row(:payments_amount) {
            link_to(
              cur(member.payments_amount),
              payments_path(q: { member_id_eq: member.id }, scope: :all))
          }
          row(:balance_amount) { cur member.balance_amount }
          row(:next_invoice_on) {
            if member.billable?
              if Current.acp.recurring_billing?
                invoicer = Billing::Invoicer.new(member)
                if invoicer.next_date
                  span class: 'next_date' do
                    l(invoicer.next_date, format: :long_medium)
                  end
                  if authorized?(:force_recurring_billing, member) && invoicer.billable?
                    link_to t('.force_recurring_billing'), force_recurring_billing_member_path(member),
                      method: :post,
                      class: 'button',
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
        attributes_table title: t('.notes') do
          row :profession
          row(:come_from) { text_format(member.come_from) }
          row(:food_note) { text_format(member.food_note) }
          row(:note) { text_format(member.note) }
        end

        active_admin_comments
      end
    end
  end

  form do |f|
    f.inputs t('.details') do
      f.input :name
      language_input(f)
    end
    if member.pending? || member.waiting?
      f.inputs t('active_admin.resource.show.waiting_membership') do
        f.input :waiting_basket_size,
          label: BasketSize.model_name.human,
          required: false
        if Current.acp.feature_flag?(:basket_price_extra)
          f.input :waiting_basket_price_extra,
            label: Member.human_attribute_name(:basket_price_extra),
            required: false
        end
        f.input :waiting_depot, label: Depot.model_name.human
        f.input :waiting_alternative_depot_ids,
          collection: Depot.all,
          as: :check_boxes,
          hint: false
        if BasketComplement.any?
          complements = BasketComplement.all
          f.has_many :members_basket_complements, allow_destroy: true do |ff|
            ff.input :basket_complement,
              collection: complements,
              prompt: true
            ff.input :quantity
          end
        end
      end
    end
    f.inputs Member.human_attribute_name(:address) do
      f.input :address
      f.input :city
      f.input :zip
      f.input :country_code,
        as: :select,
        collection: countries_collection
    end
    f.inputs Member.human_attribute_name(:delivery_address) do
      f.input :delivery_address
      f.input :delivery_city
      f.input :delivery_zip
    end
    f.inputs Member.human_attribute_name(:contact) do
      f.input :emails, as: :string
      f.input :phones, as: :string
      if Current.acp.languages.many?
        f.input :language,
          as: :select,
          collection: ACP.languages.map { |l| [t("languages.#{l}"), l] },
          prompt: true
      end
      if Current.acp.feature?('contact_sharing')
        f.input :contact_sharing
      end
    end
    f.inputs t('active_admin.resource.show.billing') do
      f.input :billing_year_division,
        as: :select,
        collection: Current.acp.billing_year_divisions.map { |i| [I18n.t("billing.year_division.x#{i}"), i] },
        prompt: true
      if Current.acp.annual_fee
        f.input :annual_fee
      end
      if Current.acp.share?
        f.input :acp_shares_info
        f.input :existing_acp_shares_number
        if member.acp_shares_number.zero?
          f.input :desired_acp_shares_number
        end
      end
      f.input :salary_basket
    end
    f.inputs t('active_admin.resource.show.notes') do
      f.input :profession
      f.input :come_from, input_html: { rows: 4 }
      f.input :food_note, input_html: { rows: 4 }
      f.input :note, input_html: { rows: 4 }, placeholder: false
    end
    f.actions
  end

  permit_params \
    :name, :language, :emails, :phones,
    :address, :city, :zip, :country_code,
    :delivery_address, :delivery_city, :delivery_zip,
    :annual_fee, :salary_basket, :billing_year_division,
    :acp_shares_info, :existing_acp_shares_number, :desired_acp_shares_number,
    :waiting, :waiting_basket_size_id, :waiting_basket_price_extra, :waiting_depot_id,
    :profession, :come_from, :food_note, :note,
    :contact_sharing,
    waiting_alternative_depot_ids: [],
    members_basket_complements_attributes: [
      :id, :basket_complement_id, :quantity, :_destroy
    ]

  action_item :validate, only: :show, if: -> { authorized?(:validate, resource) } do
    link_to t('.validate'), validate_member_path(resource), method: :post
  end
  action_item :wait, only: :show, if: -> { authorized?(:wait, resource) } do
    link_to t('.wait'), wait_member_path(resource), method: :post
  end
  action_item :deactivate, only: :show, if: -> { authorized?(:deactivate, resource) } do
    link_to t('.deactivate'), deactivate_member_path(resource), method: :post
  end
  action_item :create_membership, only: :show, if: -> { resource.waiting? && authorized?(:create, Membership) && Delivery.next } do
    next_delivery = Delivery.next
    params = {
      member_id: resource.id,
      started_on: [Date.current, next_delivery.fy_range.min, next_delivery.date.beginning_of_week].max
    }
    params[:basket_size_id] = resource.waiting_basket_size_id if resource.waiting_basket_size_id&.positive?
    params[:basket_price_extra] = resource.waiting_basket_price_extra if resource.waiting_basket_price_extra&.positive?
    params[:depot_id] = resource.waiting_depot_id if resource.waiting_depot_id&.positive?
    params[:subscribed_basket_complement_ids] = resource.waiting_basket_complement_ids if resource.waiting_basket_complement_ids&.any?
    link_to t('.create_membership'), new_membership_path(params)
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
    session = resource.sessions.create!(
      email: current_admin.email,
      remote_addr: request.remote_addr,
      user_agent: "Admin ID: #{current_admin.id}")
    redirect_to members_session_url(
      session.token,
      subdomain: Current.acp.members_subdomain,
      locale: I18n.locale)
  end

  member_action :force_recurring_billing, method: :post do
    if invoice = Billing::Invoicer.force_invoice!(resource)
      redirect_to invoice
    else
      redirect_back fallback_location: resource
    end
  end

  before_save do |member|
    member.audit_session = current_session
  end

  controller do
    include TranslatedCSVFilename

    def apply_sorting(chain)
      params[:order] ||= 'members.waiting_started_at_asc' if params[:scope] == 'waiting'
      super
    end

    def scoped_collection
      collection = Member.all
      if request.format.csv?
        collection = collection.includes(
          :waiting_basket_size,
          :waiting_depot,
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

  config.per_page = 50
  config.sort_order = 'name_asc'
end
