ActiveAdmin.register Gribouille do
  menu false

  form title: "Gribouille du #{Delivery.coming.first&.date}" do |f|
    delivery = Delivery.coming.first
    gribouille = Delivery.coming.first.gribouille
    if delivery
      date = delivery.date
      gribouille = delivery.gribouille
      if gribouille && gribouille.sent_at?
        panel 'Info' do "<h1>Gribouilles envoyées!</h1>".html_safe end
      else
        panel 'Comment que ça marche?' do
          [
            "<p>Si au moins les textes \"en-tête\" et \"contenu du panier\" sont remplis la gribouille sera envoyée à tous les membres le mardi #{Delivery.coming.first.date - 1.day} à midi.</p>",
            "<p>Chaque texte vide ne sera pas inclus dans la gribouille.</p>"
          ].join('').html_safe
        end
        f.inputs 'Textes' do
          f.input :header, as: :html_editor
          f.input :basket_content, as: :html_editor
          f.input :fields_echo, as: :html_editor
          f.input :events, as: :html_editor
          f.input :footer, as: :html_editor
        end
        f.actions
      end
    else
      panel 'Info' do "<h1>Aucune prochaine livraison à l'horizon</h1>".html_safe end
    end
  end

  permit_params *%i[header basket_content fields_echo events footer]

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
