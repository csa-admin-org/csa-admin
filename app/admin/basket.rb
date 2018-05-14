ActiveAdmin.register Basket do
  menu false
  actions :edit, :update

  form do |f|
    f.inputs do
      f.input :basket_size, prompt: true, input_html: { class: 'js-reset_price' }
      f.input :basket_price, hint: true
      f.input :quantity
      f.input :distribution, prompt: true, input_html: { class: 'js-reset_price' }
      f.input :distribution_price, hint: true
      if BasketComplement.any?
        f.has_many :baskets_basket_complements, allow_destroy: true do |ff|
          ff.input :basket_complement,
            collection: BasketComplement.all,
            prompt: true,
            input_html: { class: 'js-reset_price' }
          ff.input :price, hint: true
          ff.input :quantity
        end
      end
    end
    f.actions do
      f.action :submit, as: :input
      f.action :cancel, as: :link
    end
  end

  permit_params \
   :basket_size_id, :basket_price, :quantity,
   :distribution_id, :distribution_price,
   baskets_basket_complements_attributes: [
    :id, :basket_complement_id,
    :price, :quantity,
    :_destroy
  ]

  controller do
    def update
      super do
        redirect_to resource.membership and return if resource.valid?
      end
    end
  end
end
