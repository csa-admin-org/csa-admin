ActiveAdmin.register Delivery do
  menu parent: 'Autre', priority: 10

  scope :current_year, default: true
  scope :next_year

  index do
    column '#', ->(delivery) { delivery.number }
    column :date
    actions if current_admin.email == 'thibaud@thibaud.gg'
  end

  show do |delivery|
    attributes_table do
      row('#') { delivery.number }
      row(:date) { l delivery.date }
    end
  end

  controller do
    def show
      @delivery = resource
      respond_to do |format|
        format.html
        format.xlsx do
          render(
            xlsx: :show,
            filename: "RageDeVert-Livraison-#{@delivery.date.strftime('%Y%m%d')}"
          )
        end
      end
    end
  end

  config.filters = false
  config.sort_order = 'date_asc'
  config.per_page = 40
end
