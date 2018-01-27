ActiveAdmin.register Basket do
  menu false
  actions :edit, :update

  form do |f|
    f.inputs do
      f.input :basket_size, include_blank: false
      f.input :distribution, include_blank: false
      if BasketComplement.any?
        f.input :complement_ids,
          as: :check_boxes,
          collection: BasketComplement.all
      end
    end
    f.actions do
      f.action :submit, as: :input
      f.action :cancel, as: :link, label: 'Annuler'
    end
  end

  permit_params :basket_size_id, :distribution_id, complement_ids: []

  controller do
    def update
      super do |format|
        redirect_to resource.membership and return if resource.valid?
      end
    end
  end
end
