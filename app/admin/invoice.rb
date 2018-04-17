ActiveAdmin.register Invoice do
  menu parent: 'Facturation', priority: 1
  actions :all, except: [:edit, :update, :destroy]

  scope :all
  scope :not_sent
  scope :open, default: true
  scope :with_overdue_notice
  scope :closed
  scope :canceled

  includes :member, pdf_file_attachment: :blob
  index do
    column :id, ->(i) { auto_link i, i.id }
    column :date, ->(i) { l i.date, format: :number }
    column :member
    column :amount, ->(invoice) { number_to_currency(invoice.amount) }
    column :balance, ->(invoice) { number_to_currency(invoice.balance) }
    column 'Rap.',  ->(invoice) { invoice.overdue_notices_count }
    column :state, ->(invoice) { status_tag invoice.state }
    actions defaults: true do |invoice|
      link_to 'PDF', rails_blob_path(invoice.pdf_file, disposition: 'attachment'), class: 'pdf_link'
    end
  end

  csv do
    column :id
    column :member_id
    column(:name) { |i| i.member.name }
    column :date
    column(:object) { |i| t_invoice_object_type(i.object_type) }
    column :amount
    column :balance
    column :overdue_notices_count
    column(:state) { |i| i.state_i18n_name }
  end

  filter :id, as: :numeric
  filter :member,
    as: :select,
    collection: -> { Member.order(:name) }
  filter :object_type,
    as: :select,
    collection: -> { object_type_collection }
  filter :date

  sidebar I18n.t('active_admin.sidebars.total'), only: :index do
    all = collection.limit(nil)
    span t('active_admin.sidebars.amount')
    span number_to_currency(all.sum(:amount)), style: 'float: right; font-weight: bold;'
  end

  show do |invoice|
    columns do
      column do
        panel link_to('Paiements directs', payments_path(q: { invoice_id_equals: invoice.id, member_id_eq: invoice.member_id }, scope: :all)) do
          payments = invoice.payments.order(:date)
          if payments.none?
            em 'Aucun paiement'
          else
            table_for(payments, class: 'table-payments') do |payment|
              column(:date) { |p| auto_link p, l(p.date, format: :number) }
              column(:amount) { |p| number_to_currency(p.amount) }
              column(:type) { |p| status_tag p.type }
            end
          end
        end
      end

      column do
        attributes_table do
          row :id
          row :member
          row(:object) { display_object(invoice) }
          row(:date) { l invoice.date }
          row(:state) { status_tag invoice.state }
          row(:sent_at) { l invoice.sent_at if invoice.sent_at }
          row(:updated_at) { l invoice.updated_at }
        end

        attributes_table title: 'Montant' do
          row(:amount) { number_to_currency(invoice.amount) }
          row(:balance) { number_to_currency(invoice.balance) }
        end

        attributes_table title: 'Rappels' do
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

  action_item :send_email, only: :show, if: -> { authorized?(:send_email, resource) } do
    link_to 'Envoyer', send_email_invoice_path(resource), method: :post
  end

  action_item :cancel, only: :show, if: -> { authorized?(:cancel, resource) } do
    link_to 'Annuler', cancel_invoice_path(resource), method: :post
  end

  member_action :send_email, method: :post do
    resource.send!
    redirect_to resource_path, notice: "Email envoyé!"
  end

  member_action :cancel, method: :post do
    resource.cancel!
    redirect_to resource_path, notice: "Facture annulée"
  end

  form do |f|
    f.inputs t('.details') do
      f.input :member,
        collection: Member.order(:name).distinct,
        include_blank: false,
        input_html: { onchange: "self.location='#{new_invoice_path}?member_id='+$(this).val();" }
      f.hidden_field :object_id
      f.hidden_field :object_type
      f.input :date, as: :datepicker, include_blank: false
      unless f.object.persisted?
        f.input :comment, as: :text
      end
    end
    tabs do
      tab halfdays_human_name, id: 'halfday_participation' do
        f.inputs do
          if f.object.object.is_a?(HalfdayParticipation)
            li class: 'refused_halfday_participation' do
              (
                link_to("Participation refusée du #{f.object.object.halfday.date}", halfday_participation_path(f.object.object_id)) +
                ' – ' +
                link_to('Effacer', new_invoice_path(member_id: f.object.member_id))
              ).html_safe
            end
          end
          f.input :paid_missing_halfday_works, as: :number, min: 0, max: 99999.95, step: 0.05
          f.input :amount, as: :number, min: 0, max: 99999.95, step: 0.05
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
    :amount,
    :comment,
    :paid_missing_halfday_works

  before_build do |invoice|
    if params[:halfday_participation_id]
      hp = HalfdayParticipation.find(params[:halfday_participation_id])
      invoice.member = hp.member
      invoice.object = hp
      invoice.paid_missing_halfday_works = hp.participants_count
      invoice.amount = hp.participants_count * ACP::HALFDAY_PRICE
    elsif params[:member_id]
      member = Member.find(params[:member_id])
      invoice.member = member
    end
    invoice.member_id ||= referer_filter_member_id
    invoice.object_type ||= 'HalfdayParticipation'
    invoice.paid_missing_halfday_works ||= 1
    invoice.amount ||= ACP::HALFDAY_PRICE

    invoice.date ||= Date.current
    invoice.amount ||= 0
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
