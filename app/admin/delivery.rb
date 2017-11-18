ActiveAdmin.register Delivery do
  menu parent: 'Autre', priority: 10

  scope :current_year, default: true
  scope :next_year

  # Workaround for ActionController::UnknownFormat (xlsx download)
  # https://github.com/activeadmin/activeadmin/issues/4945#issuecomment-302729459
  index download_links: -> { params[:action] == 'show' ? [:xlsx] : nil } do
    column '#', ->(delivery) { delivery.number }
    column :date
    column :note
    actions if current_admin.email == 'thibaud@thibaud.gg'
  end

  show do |delivery|
    attributes_table do
      row('#') { delivery.number }
      row(:date) { l delivery.date }
      row(:note)
    end
  end

  controller do
    def show
      @delivery = resource
      respond_to do |format|
        format.html
        format.xlsx do
          render(xlsx: :show,
            filename: "RageDeVert-Livraison-#{@delivery.date.strftime('%Y%m%d')}"
          )
        end
      end
    end

    def update
      super do |success, _failure|
        success.html { redirect_to root_path }
      end
    end
  end

  permit_params :date, :note

  config.filters = false
  config.sort_order = 'date_asc'
  config.per_page = 40
end
