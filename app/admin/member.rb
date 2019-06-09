ActiveAdmin.register Member do
  menu priority: 2

  scope :all
  scope :pending
  scope :waiting
  scope :active, default: true
  scope :support
  scope :inactive

  filter :with_name, as: :string
  filter :with_address, as: :string
  filter :with_phone, as: :string
  filter :with_email, as: :string
  filter :city, as: :select, collection: -> {
    Member.pluck(:city).uniq.map(&:presence).compact.sort
  }
  filter :billing_year_division,
    as: :select,
    collection: -> { Current.acp.billing_year_divisions.map { |i| [I18n.t("billing.year_division.x#{i}"), i] } }
  filter :salary_basket,
    as: :boolean,
    if: proc { params[:scope].in? ['active', nil] }

  index do
    if params[:scope] == 'waiting'
      @waiting_started_ats ||= Member.waiting.order(:waiting_started_at).pluck(:waiting_started_at)
      column '#', ->(member) {
        @waiting_started_ats.index(member.waiting_started_at) + 1
      }, sortable: :waiting_started_at
    end
    column :name, ->(member) { auto_link member }
    column :city, ->(member) { member.city? ? "#{member.city} (#{member.zip})" : '–' }
    column :state, ->(member) { status_tag(member.state) }
    actions
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
    column(:delivery_address)
    column(:delivery_zip)
    column(:delivery_city)
    column(:profession)
    column(:billing_year_division) { |m| t("billing.year_division.x#{m.billing_year_division}") }
    if Current.acp.annual_fee
      column(:annual_fee) { |m| number_to_currency(m.annual_fee) }
    end
    if Current.acp.share?
      column(:acp_shares_number)
    end
    column(:salary_basket, &:salary_basket?)
    column(:waiting_started_at)
    column(:waiting_basket_size) { |m| m.waiting_basket_size&.name }
    if BasketComplement.any?
      column(:waiting_basket_complements) { |m| m.waiting_basket_complements.map(&:name).join(', ') }
    end
    column(:waiting_depot) { |m| m.waiting_depot&.name }
    column(:food_note)
    column(:note)
    column(:validated_at)
    column(:created_at)
    column(:invoices_amount) { |m| number_to_currency m.invoices_amount }
    column(:payments_amount) { |m| number_to_currency m.payments_amount }
    column(:balance_amount) { |m| number_to_currency m.balance_amount }
  end

  show do |member|
    columns do
      column do
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
                column(ActivityParticipation.human_attribute_name(:description)) { |ap|
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
              column(:amount) { |i| number_to_currency(i.amount) }
              column(:balance) { |i| number_to_currency(i.balance) }
              column(:overdue_notices_count)
              column(:status) { |i| status_tag i.state }
              column(class: 'col-actions') { |i|
                link_to 'PDF', rails_blob_path(i.pdf_file, disposition: 'attachment'), class: 'pdf_link'
              }
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
              column(:date) { |p| auto_link p, l(p.date, format: :number) }
              column(:invoice_id) { |p| p.invoice_id ? auto_link(p.invoice, p.invoice_id) : '–' }
              column(:amount) { |p| number_to_currency(p.amount) }
              column(:type) { |p| status_tag p.type }
            end
            if payments_count > 6
              em link_to(t('.show_more'), all_payments_path), class: 'show_more'
            end
          end
        end

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

      column do
        attributes_table do
          row(:id) {
            txt = member.id.to_s
            if authorized?(:become, resource)
              txt << " – #{link_to t('.become_member'), become_member_path(resource), method: :post}"
            end
            txt.html_safe
          }
          row :name
          row(:status) { status_tag member.state }
          if Current.acp.languages.many?
            row(:language) { t("languages.#{member.language}") }
          end
          row(:created_at) { l member.created_at }
          row(:validated_at) { member.validated_at ? l(member.validated_at) : nil }
          row :validator
        end
        if member.pending? || member.waiting?
          attributes_table title: t('.waiting_membership') do
            if member.waiting?
              row :waiting_started_at
            end
            row(:basket_size) { member.waiting_basket_size&.name }
            if BasketComplement.any?
              row(:basket_complements) {
                member.waiting_basket_complements.map(&:name).to_sentence
              }
            end
            row(:depot) { member.waiting_depot&.name }
          end
        end
        attributes_table title: Member.human_attribute_name(:address) do
          span member.display_address
        end
        unless member.same_delivery_address?
          attributes_table title: Member.human_attribute_name(:delivery_address) do
            span member.display_delivery_address
          end
        end
        attributes_table title: Member.human_attribute_name(:contact) do
          row(:emails) { display_emails(member.emails_array) }
          row(:phones) { display_phones(member.phones_array) }
          row(:newsletter) { status_tag(member.newsletter? ? :yes : :no) }
        end
        attributes_table title: t('.billing') do
          row(:billing_year_division) { t("billing.year_division.x#{member.billing_year_division}") }
          row(:salary_basket) { status_tag(member.salary_basket) }
          if Current.acp.annual_fee
            row(:annual_fee) { number_to_currency member.annual_fee }
          end
          if Current.acp.share?
            row(:acp_shares_number)
            row(:acp_shares_info) { member.acp_shares_info }
          end
          row(:invoices_amount) { number_to_currency member.invoices_amount }
          row(:payments_amount) { number_to_currency member.payments_amount }
          row(:balance_amount) { number_to_currency member.balance_amount }
        end
        attributes_table title: t('.notes') do
          row :profession
          row :come_from
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
      if Current.acp.languages.many?
        f.input :language,
          as: :select,
          collection: Current.acp.languages.map { |l| [t("languages.#{l}"), l] },
          prompt: true
      end
    end
    if member.pending? || member.waiting?
      f.inputs t('active_admin.resource.show.waiting_membership') do
        f.input :waiting_basket_size,
          label: BasketSize.model_name.human,
          required: false
        if BasketComplement.any?
          f.input :waiting_basket_complement_ids,
            label: BasketComplement.model_name.human(count: 2),
            as: :check_boxes,
            collection: BasketComplement.all
        end
        f.input :waiting_depot, label: Depot.model_name.human
      end
    end
    f.inputs Member.human_attribute_name(:address) do
      f.input :address
      f.input :city
      f.input :zip
    end
    f.inputs Member.human_attribute_name(:delivery_address) do
      f.input :delivery_address
      f.input :delivery_city
      f.input :delivery_zip
    end
    f.inputs Member.human_attribute_name(:contact) do
      f.input :emails, as: :string
      f.input :phones, as: :string
      f.input :newsletter, as: :select,
        collection: [[t('formtastic.yes'), true], [t('formtastic.no'), false]],
        include_blank: true
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
      end
      f.input :salary_basket
    end
    f.inputs t('active_admin.resource.show.notes') do
      f.input :profession
      f.input :come_from
      f.input :food_note, input_html: { rows: 3 }
      f.input :note, input_html: { rows: 3 }, placeholder: false
    end
    f.actions
  end

  permit_params \
    :name, :language, :address, :city, :zip, :emails, :phones, :newsletter,
    :delivery_address, :delivery_city, :delivery_zip,
    :annual_fee, :salary_basket, :billing_year_division,
    :acp_shares_info, :existing_acp_shares_number,
    :waiting, :waiting_basket_size_id, :waiting_depot_id,
    :profession, :come_from, :food_note, :note,
    waiting_basket_complement_ids: []

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
    link_to t('.create_membership'),
      new_membership_path(
        member_id: resource.id,
        basket_size_id: resource.waiting_basket_size_id,
        depot_id: resource.waiting_depot_id,
        subscribed_basket_complement_ids: resource.waiting_basket_complement_ids,
        started_on: [Date.current, next_delivery.fy_range.min, next_delivery.date.beginning_of_week].max)
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

  member_action :become, method: :post do
    session = resource.sessions.create!(
      email: current_admin.email,
      remote_addr: request.remote_addr,
      user_agent: "Admin ID: #{current_admin.id}")
    redirect_to members_session_url(session.token, locale: I18n.locale)
  end

  controller do
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
        object.validate!(current_admin) if object.valid?
      end
    end
  end

  config.per_page = 50
  config.sort_order = 'name_asc'
end
