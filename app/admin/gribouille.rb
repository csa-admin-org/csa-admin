ActiveAdmin.register Gribouille do
  menu priority: 9

  form do |f|
    delivery = Delivery.coming.first
    gribouille = delivery.gribouille
    if delivery
      date = delivery.date
      gribouille = delivery.gribouille
      if gribouille&.sent_at?
        panel 'Info' do "<h1>Gribouilles envoyées!</h1>".html_safe end
      else
        panel 'Comment que ça marche?' do
          [
            "<p>Si au moins les textes \"en-tête\" et \"contenu du panier\" sont remplis la gribouille sera envoyée à tous les membres le mardi #{delivery.date - 1.day} à midi.</p>",
            "<p>Chaque texte vide ne sera pas inclus dans la gribouille.</p>"
          ].join('').html_safe
        end
        f.inputs 'Textes' do
          f.input :header, as: :medium_editor, input_html: { data: { options: '{"placeholder":{"text":"Doit être rempli"},"spellcheck":false,"toolbar":{"buttons":["bold","italic","underline","anchor","unorderedlist","orderedlist"]}}' } }
          f.input :basket_content, as: :medium_editor, input_html: { data: { options: '{"placeholder":{"text":"Doit être rempli"},"spellcheck":false,"toolbar":{"buttons":["bold","italic","underline","anchor","unorderedlist","orderedlist"]}}' } }
          f.input :fields_echo, as: :medium_editor, input_html: { data: { options: '{"placeholder":false,"spellcheck":false,"toolbar":{"buttons":["bold","italic","underline","anchor","unorderedlist","orderedlist"]}}' } }
          f.input :events, as: :medium_editor, input_html: { data: { options: '{"placeholder":false,"spellcheck":false,"toolbar":{"buttons":["bold","italic","underline","anchor","unorderedlist","orderedlist"]}}' } }
          f.input :footer, as: :medium_editor, input_html: { data: { options: '{"placeholder":false,"spellcheck":false,"toolbar":{"buttons":["bold","italic","underline","anchor","unorderedlist","orderedlist"]}}' } }
        end
        f.inputs 'Pièce jointes', multipart: true do
          Gribouille::ATTACHMENTS_NUMBER.times.each do |i|
            if gribouille&.send("attachment_name_#{i}")
              f.input "attachment_name_#{i}".to_sym, as: :boolean, label: gribouille.send("attachment_name_#{i}"), input_html: { checked: 'checked' }
            else
              f.input "attachment_#{i}".to_sym, as: :file
            end
          end
        end
        f.actions
      end
    else
      panel 'Info' do "<h1>Aucune prochaine livraison à l'horizon</h1>".html_safe end
    end
  end

  permit_params *%i[
    header basket_content fields_echo events footer
    attachment_0 attachment_name_0
    attachment_1 attachment_name_1
    attachment_2 attachment_name_2
  ]

  before_build do
    gribouille = Delivery.coming.first.gribouille
    @resource = gribouille if gribouille
  end

  before_create do |gribouille|
    gribouille.delivery = Delivery.coming.first
  end

  controller do
    def create
      super do |_|
        redirect_to new_gribouille_url, notice: 'Gribouille sauvegardée!' and return if resource.valid?
      end
    end
    def update
      super do |_|
        redirect_to new_gribouille_url, notice: 'Gribouille sauvegardée!' and return if resource.valid?
      end
    end
  end
end
