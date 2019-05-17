ActiveAdmin.register Invoice do
  menu parent: :billing, priority: 1
  actions :all, except: %i[edit update]

  scope :all_without_canceled
  scope :unpaid, default: true
  scope :with_overdue_notice
  scope :closed
  scope :canceled

  includes :payments, pdf_file_attachment: :blob, member: :last_membership
  index do
    column :id, ->(i) { auto_link i, i.id }
    column :date, ->(i) { l i.date, format: :number }
    column :member
    column :amount, ->(invoice) { number_to_currency(invoice.amount) }
    column :balance, ->(invoice) { number_to_currency(invoice.balance) }
    column :overdue_notices_count
    column :state, ->(invoice) { status_tag invoice.state }
    actions defaults: true do |invoice|
      link_to 'PDF', rails_blob_path(invoice.pdf_file, disposition: 'attachment'), class: 'pdf_link'
    end
  end

  csv do
    column :id
    column :member_id
    column(:name) { |i| i.member.name }
    column(:emails) { |i| i.member.emails_array.join(', ') }
    column(:last_membership_ended_on) { |i| i.member.last_membership&.ended_on }
    column :date
    column(:object) { |i| t_invoice_object_type(i.object_type) }
    column :amount
    column :balance
    column :overdue_notices_count
    column :state, &:state_i18n_name
  end

  filter :id, as: :numeric
  filter :member,
    as: :select,
    collection: -> { Member.order(:name) }
  filter :object_type,
    as: :check_boxes,
    collection: -> { object_type_collection }
  filter :amount
  filter :date

  sidebar I18n.t('active_admin.sidebars.total'), only: :index do
    all = collection.unscope(:includes).limit(nil)

    if Array(params.dig(:q, :object_type_in)).include?('Membership') && Current.acp.annual_fee?
      div class: 'total' do
        span Membership.model_name.human(count: 2)
        span number_to_currency(all.sum(:memberships_amount)), style: 'float: right'
      end
      div class: 'total' do
        span t('billing.annual_fees')
        span number_to_currency(all.sum(:annual_fee)), style: 'float: right;'
      end
      div class: 'totals' do
        span t('active_admin.sidebars.amount')
        span number_to_currency(all.sum(:amount)), style: 'float: right; font-weight: bold;'
      end
    elsif params[:scope].in? ['unpaid', nil]
      div class: 'total' do
        span t('billing.scope.missing')
        span number_to_currency(all.sum('amount - balance')), style: 'float: right'
      end
      div class: 'total' do
        span t('billing.scope.paid')
        span number_to_currency(all.sum(:balance)), style: 'float: right;'
      end
      div class: 'totals' do
        span t('active_admin.sidebars.amount')
        span number_to_currency(all.sum(:amount)), style: 'float: right; font-weight: bold;'
      end
    else
      div do
        span t('active_admin.sidebars.amount')
        span number_to_currency(all.sum(:amount)), style: 'float: right; font-weight: bold;'
      end
    end
  end

  show do |invoice|
    columns do
      column do
        panel link_to(t('.direct_payments'), payments_path(q: { invoice_id_equals: invoice.id, member_id_eq: invoice.member_id }, scope: :all)) do
          payments = invoice.payments.order(:date)
          if payments.none?
            em t('.no_payments')
          else
            table_for(payments, class: 'table-payments') do
              column(:date) { |p| auto_link p, l(p.date, format: :number) }
              column(:amount) { |p| number_to_currency(p.amount) }
              column(:type) { |p| status_tag p.type }
            end
          end
        end
        if invoice.items.any?
          panel InvoiceItem.model_name.human(count: 2) do
            table_for(invoice.items, class: 'table-payments') do
              column(:description) { |ii| ii.description }
              column(:amount) { |ii| number_to_currency(ii.amount) }
            end
          end
        end
      end

      column do
        attributes_table do
          row :id
          row :member
          row(:object) { display_object(invoice) }
          if invoice.acp_share_type?
            row(:acp_shares_number)
          end
          row(:date) { l invoice.date }
          row(:state) { status_tag invoice.state }
          row(:sent_at) { l invoice.sent_at if invoice.sent_at }
          row(:updated_at) { l invoice.updated_at }
        end

        attributes_table title: Invoice.human_attribute_name(:amount) do
          row(:amount) { number_to_currency(invoice.amount) }
          row(:balance) { number_to_currency(invoice.balance) }
          row(:missing_amount) { number_to_currency(invoice.missing_amount) }
        end

        attributes_table title: Invoice.human_attribute_name(:overdue_notices_count) do
          row :overdue_notices_count
          row(:overdue_notice_sent_at) { l invoice.overdue_notice_sent_at if invoice.overdue_notice_sent_at }
        end

        active_admin_comments
      end
    end
  end

  action_item :pdf, only: :show do
    link_to 'PDF', rails_blob_path(resource.pdf_file, disposition: 'attachment')
  end

  action_item :new_payment, only: :show, if: -> { authorized?(:create, Payment) } do
    link_to t('.new_payment'), new_payment_path(
      invoice_id: invoice.id, amount: [invoice.amount, invoice.missing_amount].min)
  end

  action_item :refund, only: :show, if: -> { invoice.can_refund? } do
    acp_shares_number = [invoice.acp_shares_number, invoice.member.acp_shares_number].min
    link_to t('.refund'),
      new_invoice_path(member_id: invoice.member_id, acp_shares_number: -acp_shares_number, anchor: 'acp_share')
  end

  action_item :send_email, only: :show, if: -> { authorized?(:send_email, resource) } do
    link_to t('.send_email'), send_email_invoice_path(resource), method: :post
  end

  action_item :cancel, only: :show, if: -> { authorized?(:cancel, resource) } do
    link_to t('.cancel_invoice'), cancel_invoice_path(resource), method: :post, data: { confirm: t('.link_confirm') }
  end

  member_action :send_email, method: :post do
    resource.send!
    redirect_to resource_path, notice: t('.flash.notice')
  end

  member_action :cancel, method: :post do
    resource.cancel!
    redirect_to resource_path, notice: t('.flash.notice')
  end

  form do |f|
    f.inputs t('.details') do
      f.input :member,
        collection: Member.order(:name).distinct,
        prompt: true,
        input_html: { onchange: "self.location='#{new_invoice_path}?member_id='+$(this).val();" }
      f.hidden_field :object_id
      f.hidden_field :object_type
      f.input :date, as: :datepicker
      unless f.object.persisted?
        f.input :comment, as: :text
      end
    end
    tabs do
      if Current.acp.feature?('activity')
        tab activities_human_name, id: 'activity_participation' do
          f.inputs do
            if f.object.object.is_a?(ActivityParticipation)
              li class: 'refused_activity_participation' do
                (
                  link_to(t('.refused_activity_participation', date: f.object.object.activity.date), activity_participation_path(f.object.object_id)) +
                  ' – ' +
                  link_to(t('.erase').downcase, new_invoice_path(member_id: f.object.member_id))
                ).html_safe
              end
            end
            f.input :paid_missing_activity_participations, as: :number, step: 1
            f.input :paid_missing_activity_participations_amount, as: :number, min: 0, max: 99999.95, step: 0.05
          end
        end
      end
      if Current.acp.share?
        tab t_invoice_object_type('ACPShare'), id: 'acp_share' do
          f.inputs do
            f.input :acp_shares_number, as: :number, step: 1
          end
        end
      end
      tab t_invoice_object_type('Other'), id: 'other' do
        f.inputs do
          f.has_many :items, new_record: t('.has_many_new_invoice_item') do |ff|
            ff.input :description
            ff.input :amount, as: :number, step: 0.05, min: 0, max: 99999.95
          end
        end
      end
    end
    f.actions
  end

  permit_params \
    :member_id,
    :object_id,
    :object_type,
    :date,
    :comment,
    :paid_missing_activity_participations,
    :paid_missing_activity_participations_amount,
    :acp_shares_number,
    items_attributes: %i[description amount]

  before_build do |invoice|
    if params[:activity_participation_id]
      ap = ActivityParticipation.find(params[:activity_participation_id])
      invoice.member = ap.member
      invoice.object = ap
      invoice.paid_missing_activity_participations = ap.participants_count
      invoice.paid_missing_activity_participations_amount =
        ap.participants_count * Current.acp.activity_price
    elsif params[:member_id]
      member = Member.find(params[:member_id])
      invoice.member = member
    end
    if params[:acp_shares_number]
      invoice.acp_shares_number ||= params[:acp_shares_number]
    end

    invoice.paid_missing_activity_participations_amount ||= Current.acp.activity_price
    invoice.member_id ||= referer_filter_member_id
    invoice.date ||= Date.current
  end

  after_create do |invoice|
    if invoice.persisted? && invoice.comment.present?
      ActiveAdmin::Comment.create!(
        resource: invoice,
        body: invoice.comment,
        author: current_admin,
        namespace: 'root')
    end
  end

  config.per_page = 50
  config.sort_order = 'date'
end
