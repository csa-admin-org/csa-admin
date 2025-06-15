# frozen_string_literal: true

ActiveAdmin.register Basket do
  menu false
  actions :index, :edit, :update

  breadcrumb do
    links = [
      link_to(Member.model_name.human(count: 2), members_path),
      auto_link(resource.membership.member),
      link_to(
        Membership.model_name.human(count: 2),
        memberships_path(q: { member_id_eq: resource.membership.member_id }, scope: :all)),
      auto_link(resource.membership)
    ]
    if params["action"].in? %W[edit]
      links << [ Basket.model_name.human, resource.delivery.display_name(format: :number) ].join(" ").html_safe
    end
    links
  end

  filter :delivery, as: :select

  includes :delivery, :basket_size, :depot, baskets_basket_complements: :basket_complement, membership: :member
  csv do
    delivery = Delivery.find(params[:q][:delivery_id_eq])
    shop_orders =
      if Current.org.feature?("shop")
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
    column(:address) { |b| b.member.address }
    column(:zip) { |b| b.member.zip }
    column(:city) { |b| b.member.city }
    column(:food_note) { |b| b.member.food_note }
    column(:delivery_note) { |b| b.member.delivery_note }
    column(:depot_id)
    column(:depot) { |b| b.depot&.public_name }
    column(:basket_size_id)
    column(I18n.t("attributes.basket_size")) { |b| b.basket_size.name }
    column(:quantity) { |b| b.quantity }
    column(:description) { |b| b.basket_description(public_name: true) }
    if BasketComplement.kept.any?
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
    if Current.org.feature?("shop")
      column(I18n.t("shop.title_orders", count: 2)) { |b|
        shop_orders.any? { |o| o.member_id == b.member.id } ? "X" : nil
      }
      if BasketComplement.kept.any?
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

  form do |f|
    delivery_collection = basket_deliveries_collection(f.object)

    if f.object.shifted?
      panel t(".basket_shift_title"), class: "bg-teal-100 mb-8", action: handbook_icon_link("absences", anchor: "basket-shift") do
        div class: "px-2 mb-2" do
          para t(".basket_shifted_description_html",
            target_date: l(f.object.shift_as_source.target_basket.delivery.date, format: :short),
            target_url: edit_basket_path(f.object.shift_as_source.target_basket)
          ), class: "description"
          para t(".basket_content", content: f.object.shift_as_source.description), class: "mt-2 text-base"
        end
      end
      f.actions do
        div link_to t(".basket_shift_destroy"), basket_shift_path(f.object.shift_as_source), method: :delete, class: "action-item-button"
        cancel_link membership_path(f.object.membership)
      end
    else
      if f.object.can_be_shifted?
        panel t(".basket_shift_title"), class: "bg-teal-100 list-none mb-8 ", action: handbook_icon_link("absences", anchor: "basket-shift") do
          div class: "px-2 -mb-2" do
            para t(".basket_shift_explanation"), class: "description"
            f.input :shift_target_basket_id, as: :select, collection: basket_shift_targets_collection(f.object), include_blank: true
          end
        end
      end

      if f.object.shifts_as_target.any?
        panel t(".basket_shift_title"), class: "bg-teal-100 mb-8", action: handbook_icon_link("absences", anchor: "basket-shift") do
          div class: "px-2 mb-2" do
            para t(".basket_shift_targets_explanation"), class: "description"
            ul class: "list-disc list-outside mt-4 ml-6 space-y-2 text-base" do
              shifts = f.object.shifts_as_target.includes(source_basket: :delivery)
              shifts.sort_by { |s| s.source_basket.delivery.date }.each do |shift|
                li do
                  div class: "flex items-start gap-2" do
                    span t(".basket_shift_target_description",
                        source_date: l(shift.source_basket.delivery.date, format: :short),
                        description: shift.description)
                    span do
                      link_to t(".destroy"), basket_shift_path(shift), method: :delete, class: "action-item-button small"
                    end
                  end
                end
              end
            end
          end
        end
      end

      f.inputs Delivery.model_name.human(count: 1), "data-controller" => "form-reset" do
        f.input :depot,
          prompt: true,
          input_html: { data: { action: "form-reset#reset" } }
        if Depot.prices?
          f.input :depot_price,
            hint: true,
            required: false,
            input_html: { data: { form_reset_target: "input" } }
        end
        if delivery_collection.many?
          f.input :delivery,
            collection: delivery_collection,
            prompt: true
        end
        if DeliveryCycle.prices? || f.object.delivery_cycle_price&.positive?
          f.input :delivery_cycle_price, required: false, min: 0
        end
      end
      f.inputs [
        Basket.model_name.human(count: 1),
        BasketComplement.kept.any? ? Membership.human_attribute_name(:memberships_basket_complements) : nil
      ].compact.to_sentence, "data-controller" => "form-reset" do
        f.input :basket_size,
          prompt: true,
          collection: admin_basket_sizes_collection,
          input_html: { data: { action: "form-reset#reset" } }
        f.input :basket_price,
          hint: true,
          required: false,
          input_html: { data: { form_reset_target: "input" } }
        if Current.org.feature?("basket_price_extra")
          f.input :price_extra, required: true, label: Current.org.basket_price_extra_title
        end
        f.input :quantity
        if BasketComplement.kept.any?
          f.has_many :baskets_basket_complements, allow_destroy: true, data: { controller: "form-reset" } do |ff|
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
      f.actions do
        f.action :submit, as: :input
        cancel_link membership_path(f.object.membership)
      end
    end
  end

  permit_params \
    :shift_target_basket_id,
    :basket_size_id, :basket_price, :price_extra, :quantity,
    :delivery_id,
    :depot_id, :depot_price, :delivery_cycle_price,
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
