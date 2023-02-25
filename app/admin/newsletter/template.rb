ActiveAdmin.register Newsletter::Template do
  menu false
  actions :all, except: [:show]

  breadcrumb do
    links = [link_to(Newsletter.model_name.human(count: 2), newsletters_path)]
    if params[:action] != 'index'
      links << link_to(Newsletter::Template.model_name.human(count: 2), newsletter_templates_path)
    end
    links
  end

  includes :newsletters
  index download_links: false do
    column :title, ->(t) { link_to t.title, [:edit, t] }, sortable: true
    column :newsletters, ->(t) {
      link_to t.newsletters.count, newsletters_path(q: { template_id_eq: t.id })
    }
    actions defaults: true, class: 'col-actions-3' do |template|
      link_to(t('.duplicate'), new_newsletter_template_path(template_id: template.id), class: 'duplicate_link', title: t('.duplicate'))
    end
  end

  form data: {
    controller: 'code-editor',
    code_editor_target: 'form',
    code_editor_preview_path_value: '/newsletter_templates/preview.js'
  } do |f|
    newsletter_template = f.object
    f.inputs t('.details') do
      f.input :title
    end
    f.inputs do
      translated_input(f, :contents,
        as: :text,
        hint: t('formtastic.hints.liquid').html_safe,
        wrapper_html: { class: 'ace-editor' },
        input_html: {
          class: 'ace-editor',
          data: { mode: 'liquid', code_editor_target: 'editor' }
        })

      handbook_button(self, 'newsletters', anchor: 'templates')
    end
    columns 'data-controller' => 'iframe-resize' do
      Current.acp.languages.each do |locale|
        column do
          title = t('.preview')
          title += " (#{t("languages.#{locale}")})" if Current.acp.languages.many?
          f.inputs title do
            div class: 'iframe-wrapper' do
              iframe(
                srcdoc: newsletter_template.mail_preview(locale),
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
                name: "newsletter_template[liquid_data_preview_yamls][#{locale}]"
              })
          end
        end
      end
    end
    f.actions
  end

  permit_params(
    :title,
    *I18n.available_locales.map { |l| "content_#{l}" },
    liquid_data_preview_yamls: I18n.available_locales)

  collection_action :preview, method: :get do
    @newsletter_template = resource_class.new
    resource.assign_attributes(permitted_params[:newsletter_template])
    render 'mail_templates/preview'
  end

  before_build do |resource|
    if template = Newsletter::Template.find_by(id: params[:template_id])
      resource.title = template.title + ' (copy)'
      resource.contents = template.contents
    end
  end

  controller do
    skip_before_action :verify_authenticity_token, only: :preview
  end

  config.filters = false
  config.sort_order = :title_asc
end
