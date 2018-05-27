ActiveAdmin.register Member do
  menu priority: 2

  scope :all
  scope :pending
  scope :waiting
  scope :trial, if: ->(_) { Current.acp.trial_basket_count.positive? }
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
    if params[:scope] == 'trial'
      column Basket.model_name.human(count: 2), ->(member) { member.delivered_baskets.size }
    end
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
    column(:salary_basket, &:salary_basket?)
    column(:support_member, &:support_member?)
    column(:waiting_started_at)
    column(:waiting_basket_size) { |m| m.waiting_basket_size&.name }
    if BasketComplement.any?
      column(:waiting_basket_complements) { |m| m.waiting_basket_complements.map(&:name).join(', ') }
    end
    column(:waiting_distribution) { |m| m.waiting_distribution&.name }
    column(:page_url)
    column(:food_note)
    column(:note)
    column(:validated_at)
    column(:created_at)
  end

  show do |member|
    columns do
      column do
        panel link_to(Membership.model_name.human(count: 2), memberships_path(q: { member_id_eq: member.id }, scope: :all)) do
          memberships = member.memberships.includes(:delivered_baskets).order(:started_on)
          if memberships.none?
            em t('.no_memberships')
          else
            table_for(memberships, class: 'table-memberships') do
              column(:period) { |m| auto_link m, membership_short_period(m) }
              column(halfdays_human_name) { |m|
                auto_link m, "#{m.recognized_halfday_works} / #{m.halfday_works}"
              }
              column(:baskets) { |m|
                auto_link m, "#{m.delivered_baskets.size} / #{m.baskets_count}"
              }
            end
          end
        end

        halfday_participations = member.halfday_participations.includes(:halfday).order('halfdays.date, halfdays.start_time')
        count = halfday_participations.count
        panel link_to("#{halfdays_human_name} (#{count})", halfday_participations_path(q: { member_id_eq: member.id }, scope: :all)) do
          if halfday_participations.none?
            em t_halfday('.no_halfdays')
          else
            table_for(halfday_participations.offset([count - 5, 0].max), class: 'table-halfday_participations') do
              column(HalfdayParticipation.human_attribute_name(:description)) { |hp|
                auto_link hp, hp.halfday.name
              }
              column(HalfdayParticipation.human_attribute_name(:participants), &:participants_count)
              column(:state) { |hp| status_tag(hp.state) }
            end
          end
        end

        panel link_to(Invoice.model_name.human(count: 2), invoices_path(q: { member_id_eq: member.id }, scope: :all)) do
          invoices = member.invoices.includes(pdf_file_attachment: :blob).order(:date)
          if invoices.none?
            em t('.no_invoices')
          else
            table_for(invoices, class: 'table-invoices') do
              column(:id) { |i| auto_link i, i.id }
              column(:date) { |i| l(i.date, format: :number) }
              column(:amount) { |i| number_to_currency(i.amount) }
              column(:balance) { |i| number_to_currency(i.balance) }
              column(:overdue_notices_count)
              column(class: 'col-actions') { |i|
                link_to 'PDF', rails_blob_path(i.pdf_file, disposition: 'attachment'), class: 'pdf_link'
              }
              column(:status) { |i| status_tag i.state }
            end
          end
        end

        panel link_to(Payment.model_name.human(count: 2), payments_path(q: { member_id_eq: member.id }, scope: :all)) do
          payments = member.payments.includes(:invoice).order(:date)
          if payments.none?
            em t('.no_payments')
          else
            table_for(payments, class: 'table-payments') do
              column(:date) { |p| auto_link p, l(p.date, format: :number) }
              column(:invoice_id) { |p| p.invoice_id ? auto_link(p.invoice, p.invoice_id) : '–' }
              column(:amount) { |p| number_to_currency(p.amount) }
              column(:type) { |p| status_tag p.type }
            end
          end
        end
      end

      column do
        attributes_table do
          row :id
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
            row :waiting_started_at
            row(:basket_size) { member.waiting_basket_size&.name }
            if BasketComplement.any?
              row(:basket_complements) {
                member.waiting_basket_complements.map(&:name).to_sentence
              }
            end
            row(:distribution) { member.waiting_distribution&.name }
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
          row(:support_member) { status_tag(member.support_member) }
          row(:support_price) { number_to_currency member.support_price }
          row(:invoices_amount) { number_to_currency member.invoices_amount }
          row(:payments_amount) { number_to_currency member.payments_amount }
          row(:difference) { number_to_currency(member.invoices_amount - member.payments_amount) }
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
        f.input :waiting_basket_size, label: BasketSize.model_name.human
        if BasketComplement.any?
          f.input :waiting_basket_complement_ids,
            label: BasketComplement.model_name.human(count: 2),
            as: :check_boxes,
            collection: BasketComplement.all
        end
        f.input :waiting_distribution, label: Distribution.model_name.human
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
    f.inputs Member.human_attribute_name(:delivery_address) do
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
      if member.inactive? && !member.future_membership
        f.input :support_member, hint: true
      end
      f.input :support_price
      f.input :salary_basket
    end
    f.inputs t('active_admin.resource.show.notes') do
      f.input :profession
      f.input :come_from
      f.input :food_note, input_html: { rows: 3 }
      f.input :note, input_html: { rows: 3 }
    end
    f.actions
  end

  permit_params \
    :name, :language, :address, :city, :zip, :emails, :phones, :newsletter,
    :delivery_address, :delivery_city, :delivery_zip,
    :support_member, :support_price, :salary_basket, :billing_year_division,
    :waiting, :waiting_basket_size_id, :waiting_distribution_id,
    :profession, :come_from, :food_note, :note,
    waiting_basket_complement_ids: []

  action_item :validate, only: :show, if: -> { authorized?(:validate, resource) } do
    link_to t('.validate'), validate_member_path(resource), method: :post
  end
  action_item :remove_from_waiting_list, only: :show, if: -> { authorized?(:remove_from_waiting_list, resource) } do
    link_to t('.remove_from_waiting_list'), remove_from_waiting_list_member_path(resource), method: :post
  end
  action_item :put_back_to_waiting_list, only: :show, if: -> { authorized?(:put_back_to_waiting_list, resource) } do
    link_to t('.put_back_to_waiting_list'), put_back_to_waiting_list_member_path(resource), method: :post
  end
  action_item :create_membership, only: :show, if: -> { resource.waiting? && authorized?(:create, Membership) } do
    next_delivery = Delivery.next
    link_to t('.create_membership'),
      new_membership_path(
        member_id: resource.id,
        basket_size_id: resource.waiting_basket_size_id,
        distribution_id: resource.waiting_distribution_id,
        subscribed_basket_complement_ids: resource.waiting_basket_complement_ids,
        started_on: [Date.current, next_delivery.fy_range.min, next_delivery.date.beginning_of_week].max)
  end

  member_action :validate, method: :post do
    resource.validate!(current_admin)
    redirect_to member_path(resource)
  end

  member_action :remove_from_waiting_list, method: :post do
    resource.remove_from_waiting_list!
    redirect_to member_path(resource)
  end

  member_action :put_back_to_waiting_list, method: :post do
    resource.put_back_to_waiting_list!
    redirect_to member_path(resource)
  end

  before_build do |member|
    member.support_price ||= Current.acp.support_price
  end

  controller do
    def apply_sorting(chain)
      params[:order] ||= 'members.waiting_started_at_asc' if params[:scope] == 'waiting'
      super
    end

    def scoped_collection
      collection = Member.all
      collection = collection.includes(:delivered_baskets) if params[:scope] == 'trial'
      if request.format.csv?
        collection = collection.includes(
          :waiting_basket_size,
          :waiting_distribution,
          :waiting_basket_complements)
      end
      collection
    end

    def find_resource
      Member.find_by!(token: params[:id])
    end

    def create_resource(object)
      run_create_callbacks object do
        object.validated_at = Time.current
        object.validator = current_admin
        save_resource(object)
      end
    end
  end

  config.per_page = 50
  config.sort_order = 'name_asc'
end
