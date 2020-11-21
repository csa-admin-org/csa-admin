ActiveAdmin.register MailTemplate do
  menu parent: :other, priority: 99
  actions :index, :show, :edit, :update

  breadcrumb do
    case params['action']
    when 'show'
      [link_to(MailTemplate.model_name.human(count: 2), mail_templates_path)]
    when 'edit', 'update'
      [
        link_to(MailTemplate.model_name.human(count: 2), mail_templates_path),
        link_to(mail_template.display_name, mail_template)
      ]
    end
  end

  scope :all
  scope :active
  scope :inactive

  action_item :view, only: :index do
    link_to t('.settings'), edit_acp_path(anchor: 'mail')
  end

  index download_links: false do
    column :title, ->(mt) { link_to mt.display_name, mt }
    column :description
    column :active
    actions
  end

  show do |mail_template|
    columns do
      column do
        attributes_table do
          row(:description)
          row(:active)
        end
      end
    end
    mails_previews(self, mail_template)
  end

  permit_params \
    :active,
    subjects: I18n.available_locales,
    contents: I18n.available_locales,
    liquid_data_preview_yamls: I18n.available_locales

  form do |f|
    mail_template = f.object
    if mail_template.errors.none? && params.key?(:preview)
      mails_previews(self, mail_template)
      f.input :active, as: :hidden
      translated_input(f, :subjects, as: :hidden)
      translated_input(f, :contents, as: :hidden)
      translated_input(f, :liquid_data_preview_yamls, as: :hidden)
      f.actions do
        f.action :submit, label: t('.submit.preview_save')
        f.action :submit,
          label: t('.submit.preview_edit'),
          button_html: { class: 'cancel', name: 'edit' }
      end
    else
      f.inputs t('.settings') do
        # TODO: Some templates cannot be desactivated?
        # f.input :active, input_html: { disabled: true }, hint: 'Cet email ne peut pas être désactivé'
        f.input :active, hint: true
      end
      f.inputs do
        translated_input(f, :subjects,
          hint: t('formtastic.hints.liquid').html_safe)
        translated_input(f, :contents,
          as: :text,
          hint: t('formtastic.hints.liquid').html_safe,
          wrapper_html: { class: 'ace-editor' },
          input_html: { class: 'ace-editor', data: { mode: 'liquid' } })
      end
      f.inputs do
        translated_input(f, :liquid_data_preview_yamls,
          as: :text,
          hint: t('formtastic.hints.liquid_data_preview'),
          wrapper_html: { class: 'ace-editor' },
          input_html: { class: 'ace-editor', data: { mode: 'yaml' } })
      end
      f.actions do
        f.action :submit,
          label: t('.submit.preview'),
          button_html: { name: 'preview' }
        cancel_link
      end
    end
  end

  before_save do |mail_template|
    mail_template.audit_session = current_session
  end

  controller do
    def find_resource
      scoped_collection.where(title: params[:id]).first!
    end

    def update(options={}, &block)
      resource.assign_attributes(permitted_params[:mail_template])
      if resource.valid? && (params.keys & %w[preview edit]).any?
        render :edit
      else
        super do |success, _failure|
          success.html { redirect_to mail_templates_path }
        end
      end
    end
  end

  config.filters = false
end
