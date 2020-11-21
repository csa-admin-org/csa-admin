module MailTemplatesHelper
  def mails_previews(arbre, mail_template)
    arbre.columns do
      Current.acp.languages.each do |locale|
        arbre.column do
          panel_title = t('.preview')
          panel_title += " (#{I18n.t("languages.#{locale}")})" if Current.acp.languages.many?
          arbre.panel panel_title do
            arbre.iframe(
              srcdoc: mail_template.mail_preview(locale),
              class: 'mail_preview',
              id: "mail_preview_#{locale}")
          end
        end
      end
    end
  end
end
