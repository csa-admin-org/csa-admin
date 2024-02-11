ActiveAdmin.register Basket do
  menu false
  actions :index, :edit, :update

  filter :delivery, as: :select

  includes :delivery, :basket_size, :depot, baskets_basket_complements: :basket_complement, membership: :member
  csv do
    delivery = Delivery.find(params[:q][:delivery_id_eq])
    shop_orders =
      if Current.acp.feature?("shop")
        delivery.shop_orders.includes(:member, items: { product: :basket_complement })
      else
        Shop::Order.none
      end
    shop_products = shop_orders.products_displayed_in_delivery_sheets

    column(:membership_id) { |b| b.membership_id }
    column(:member_id) { |b| b.member.id }
    column(:name) { |b| b.member.name }
    column(:emails) { |b| b.member.emails_array.join(", ") }
    column(:phones) { |b| b.member.phones_array.map(&:phony_formatted).join(", ") }
    column(:address) { |b| b.member.final_delivery_address }
    column(:zip) { |b| b.member.final_delivery_zip }
    column(:city) { |b| b.member.final_delivery_city }
    column(:food_note) { |b| b.member.food_note }
    column(:delivery_note) { |b| b.member.delivery_note }
    column(:depot_id)
    column(:depot) { |b| b.depot&.public_name }
    column(:basket_size_id)
    column(I18n.t("attributes.basket_size")) { |b| b.basket_size.name }
    column(:quantity) { |b| b.quantity }
    column(:description) { |b| b.basket_description(public_name: true) }
    if BasketComplement.any?
      shop_orders ||= Shop::Order.none
      BasketComplement.for(collection, shop_orders).each do |c|
        column(c.name) { |b|
          b.baskets_basket_complements.select { |bc| bc.basket_complement_id == c.id }.sum(&:quantity) +
            shop_orders.select { |o| o.member_id == b.member.id }.sum { |o| o.items.select { |i| i.product.basket_complement_id == c.id }.sum(&:quantity) }
        }
      end
      column("#{Basket.human_attribute_name(:complement_ids)} (#{Basket.human_attribute_name(:description)})") { |b|
        b.complements_description(public_name: true)
      }
    end
    if Current.acp.feature?("shop")
      column(I18n.t("shop.title_orders", count: 2)) { |b|
        shop_orders.any? { |o| o.member_id == b.member.id } ? "X" : nil
      }
      if BasketComplement.any?
        column("#{Basket.human_attribute_name(:complement_ids)} (#{Shop::Order.model_name.human(count: 1)})") { |b|
          shop_orders.find { |o| o.member_id == b.member.id }&.complements_description
        }
      end
      if shop_products.any?
        column("#{::Shop::Product.model_name.human(count: 2)} (#{I18n.t('shop.title')})") { |b|
          order = shop_orders.find { |o| o.member_id == b.member.id }
          shop_products.map { |p|
            quantity = order&.items&.find { |i| i.product_id == p.id }&.quantity
            quantity ? "#{quantity}x #{p.name_with_single_variant}" : nil
          }.compact.join(", ")
        }
      end
    end
  end

  breadcrumb do
    links = [
      link_to(Member.model_name.human(count: 2), members_path),
      auto_link(basket.membership.member),
      link_to(
        Membership.model_name.human(count: 2),
        memberships_path(q: { member_id_eq: basket.membership.member_id }, scope: :all)),
      auto_link(basket.membership)
    ]
    if params["action"].in? %W[edit]
      links << [ Basket.model_name.human, basket.delivery.display_name(format: :number) ].join(" ")
    end
    links
  end

  form do |f|
    delivery_collection = basket_deliveries_collection(f.object)
    f.inputs [
      delivery_collection.many? ? Delivery.model_name.human(count: 1) : nil,
      Depot.model_name.human(count: 1)
    ].compact.to_sentence, "data-controller" => "form-reset" do
      if delivery_collection.many?
        f.input :delivery,
          collection: delivery_collection,
          prompt: true
      end
      f.input :depot,
        prompt: true,
        input_html: { data: { action: "form-reset#reset" } }
      f.input :depot_price,
        hint: true,
        required: false,
        input_html: { data: { form_reset_target: "input" } }
    end
    f.inputs [
      Basket.model_name.human(count: 1),
      BasketComplement.any? ? Membership.human_attribute_name(:memberships_basket_complements) : nil
    ].compact.to_sentence, "data-controller" => "form-reset" do
      f.input :basket_size,
        prompt: true,
        input_html: { data: { action: "form-reset#reset" } }
      f.input :basket_price,
        hint: true,
        required: false,
        input_html: { data: { form_reset_target: "input" } }
      if Current.acp.feature?("basket_price_extra")
        f.input :price_extra, required: true, label: Current.acp.basket_price_extra_title
      end
      f.input :quantity
      if BasketComplement.any?
        f.has_many :baskets_basket_complements, allow_destroy: true do |ff|
          ff.inputs class: "blank", "data-controller" => "form-reset" do
            ff.input :basket_complement,
              collection: basket_complements_collection(f.object),
              prompt: true,
              input_html: {
                data: {
                  action: "form-reset#reset",
                  form_select_options_filter_target: "select"
                }
              }
            ff.input :price,
              hint: true,
              required: false,
              input_html: { data: { form_reset_target: "input" } }
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
    :basket_size_id, :basket_price, :price_extra, :quantity,
    :delivery_id,
    :depot_id, :depot_price,
    baskets_basket_complements_attributes: %i[
      id basket_complement_id
      price quantity
      _destroy
    ]

  controller do
    def update
      update! do |success, failure|
        success.html { redirect_to resource.membership }
      end
    end

    def scoped_collection
      if params[:action] == "index"
        end_of_association_chain.deliverable
      else
        super
      end
    end

    def csv_filename
      delivery = Delivery.find(params[:q][:delivery_id_eq])
      [
        t("delivery.delivery"),
        delivery.display_number,
        delivery.date.strftime("%Y%m%d")
      ].join("-") + ".csv"
    end
  end
end
