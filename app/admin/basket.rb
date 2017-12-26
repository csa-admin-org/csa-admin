ActiveAdmin.register Basket do
  menu false
  actions :edit, :update

  form do |f|
    f.inputs do
      f.input :basket_size, include_blank: false
      f.input :distribution, include_blank: false
    end
    f.actions do
      f.action :submit, as: :input
      f.action :cancel, as: :link, label: 'Annuler'
    end
  end

  permit_params *%i[basket_size_id distribution_id]

  controller do
    def update
      super do |format|
        redirect_to resource.membership and return if resource.valid?
      end
    end
  end
end
