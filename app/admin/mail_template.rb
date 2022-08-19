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
  scope :member
  scope :membership
  scope -> { Activity.model_name.human }, :activity,
    if: -> { Current.acp.feature?('activity') }
  scope :invoice

  action_item :view, only: :index, if: -> { authorized?(:update, ACP) } do
    link_to t('.settings'), edit_acp_path(anchor: 'mail')
  end

  index download_links: false do
    column :title, ->(mt) { link_to mt.display_name, mt }, sortable: false
    column :description
    column :active, sortable: false
    actions class: 'col-actions-2'
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
    columns 'data-controller' => 'iframe-resize' do
      Current.acp.languages.each do |locale|
        column do
          title = t('.preview')
          title += " (#{t("languages.#{locale}")})" if Current.acp.languages.many?
          panel title do
            iframe(
              srcdoc: mail_template.mail_preview(locale),
              scrolling: 'no',
              class: 'mail_preview',
              id: "mail_preview_#{locale}",
              'data-iframe-resize-target' => 'iframe')
          end
        end
      end
    end
  end

  permit_params(
    :active,
    *I18n.available_locales.map { |l| "subject_#{l}" },
    *I18n.available_locales.map { |l| "content_#{l}" },
    liquid_data_preview_yamls: I18n.available_locales)

  form data: { controller: 'code-editor', code_editor_target: 'form' } do |f|
    mail_template = f.object
    f.inputs t('.settings') do
      li do
        para f.object.description
      end

      if mail_template.always_active?
        f.input :active,
          input_html: { disabled: true },
          required: false,
          hint: t('formtastic.hints.mail_template.always_active')
      else
        f.input :active, hint: true
      end
    end
    f.inputs do
      translated_input(f, :subjects,
        hint: t('formtastic.hints.liquid').html_safe,
        input_html: {
          data: { action: 'code-editor#updatePreview' }
        })
      translated_input(f, :contents,
        as: :text,
        hint: t('formtastic.hints.liquid').html_safe,
        wrapper_html: { class: 'ace-editor' },
        input_html: {
          class: 'ace-editor',
          data: { mode: 'liquid', code_editor_target: 'editor' }
        })
    end
    columns 'data-controller' => 'iframe-resize' do
      Current.acp.languages.each do |locale|
        column do
          title = t('.preview')
          title += " (#{t("languages.#{locale}")})" if Current.acp.languages.many?
          f.inputs title do
            div class: 'iframe-wrapper' do
              iframe(
                srcdoc: mail_template.mail_preview(locale),
                scrolling: 'no',
                class: 'mail_preview',
                id: "mail_preview_#{locale}",
                'data-iframe-resize-target' => 'iframe')
            end
            translated_input(f, :liquid_data_preview_yamls,
              locale: locale,
              as: :text,
              hint: t('formtastic.hints.liquid_data_preview'),
              wrapper_html: { class: 'ace-editor' },
              input_html: {
                class: 'ace-editor',
                data: { mode: 'yaml', code_editor_target: 'editor' },
                name: "mail_template[liquid_data_preview_yamls][#{locale}]"
              })
          end
        end
      end
    end
    f.actions
  end

  before_save do |mail_template|
    mail_template.audit_session = current_session
  end

  member_action :preview, method: :get do
    resource.assign_attributes(permitted_params[:mail_template])
    render :preview
  end

  controller do
    skip_before_action :verify_authenticity_token, only: :preview

    def scoped_collection
      scoped = end_of_association_chain
      unless Current.acp.feature?('activity')
        scoped = scoped.where.not(title: MailTemplate::ACTIVITY_TITLES)
      end
      scoped.joins(<<-SQL).order('t.ord')
        JOIN unnest(string_to_array('#{MailTemplate::TITLES.join(',')}', ','))
        WITH ORDINALITY t(title, ord)
        USING (title)
      SQL
    end

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
  config.sort_order = '' # use custom order defined in scoped_collection
end
