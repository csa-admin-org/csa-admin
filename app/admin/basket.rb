ActiveAdmin.register Basket do
  menu false
  actions :edit, :update

  breadcrumb do
    links = [
      link_to(Member.model_name.human(count: 2), members_path),
      auto_link(basket.membership.member),
      link_to(
        Membership.model_name.human(count: 2),
        memberships_path(q: { member_id_eq: basket.membership.member_id }, scope: :all)),
      auto_link(basket.membership)
    ]
    if params['action'].in? %W[edit]
      links << [Basket.model_name.human, basket.delivery.display_name(format: :number)].join(' ')
    end
    links
  end

  form  do |f|
    delivery_collection = basket_deliveries_collection(f.object)
    f.inputs [
      Depot.model_name.human(count: 1),
      delivery_collection.many? ? Delivery.model_name.human(count: 1) : nil
    ].compact.to_sentence, 'data-controller' => 'form-reset' do
      f.input :depot,
        collection: basket_depots_collection(f.object),
        prompt: true,
        input_html: { data: { action: 'form-reset#reset' } }
      f.input :depot_price,
        hint: true,
        required: false,
        input_html: { data: { form_reset_target: 'input' } }
      if delivery_collection.many?
        f.input :delivery,
          collection: delivery_collection,
          prompt: true,
          input_html: { class: 'js-update_basket_depot_options' }
      end
    end
    f.inputs [
      Basket.model_name.human(count: 1),
      BasketComplement.any? ? Membership.human_attribute_name(:memberships_basket_complements) : nil
    ].compact.to_sentence, 'data-controller' => 'form-reset' do
      f.input :basket_size,
        prompt: true,
        input_html: { data: { action: 'form-reset#reset' } }
      f.input :basket_price,
        hint: true,
        required: false,
        input_html: { data: { form_reset_target: 'input' } }
      f.input :quantity
      if BasketComplement.any?
        f.has_many :baskets_basket_complements, allow_destroy: true do |ff|
          ff.inputs class: 'blank', 'data-controller' => 'form-reset' do
            ff.input :basket_complement,
              collection: basket_complements_collection(f.object),
              prompt: true,
              input_html: { data: { action: 'form-reset#reset' } }
            ff.input :price,
              hint: true,
              required: false,
              input_html: { data: { form_reset_target: 'input' } }
            ff.input :quantity
          end
        end
      end
    end
    f.actions do
      f.action :submit, as: :input
      cancel_link membership_path(f.object.membership)
    end
  end

  permit_params \
    :basket_size_id, :basket_price, :quantity,
    :delivery_id,
    :depot_id, :depot_price,
    baskets_basket_complements_attributes: %i[
      id basket_complement_id
      price quantity
      _destroy
    ]

  controller do
    include TranslatedCSVFilename

    def update
      update! do |success, failure|
        success.html { redirect_to resource.membership }
      end
    end
  end
end
