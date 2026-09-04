# frozen_string_literal: true

ActiveAdmin.register HomeDeliveryAddress do
  menu false
  actions :all, except: [ :index, :show ]

  breadcrumb do
    links = [ link_to(Member.model_name.human(count: 2), members_path) ]
    member = resource.member
    links << auto_link(member) if member
    if params[:action] == "edit"
      links << HomeDeliveryAddress.model_name.human
    end
    links
  end

  form do |f|
    f.inputs t(".details"), icon: "notebook-text" do
      f.input :member_id, as: :hidden unless f.object.persisted?
      f.input :member,
        collection: f.object.member ? [ [ f.object.member.name, f.object.member_id ] ] : [],
        input_html: { disabled: true }
      f.input :name
      f.input :street
      div class: "single-line" do
        f.input :zip, wrapper_html: { class: "col-zip" }
        f.input :city, wrapper_html: { class: "is-full" }
      end
      f.input :note, as: :text, input_html: { rows: 3 }
    end

    if f.object.member
      baskets = HomeDeliveryAddress.eligible_baskets_for(
        f.object.member,
        keep_delivery_ids: f.object.delivery_ids).includes(:delivery, :depot)
      if baskets.any?
        taken_ids = HomeDeliveryAddress.taken_delivery_ids_for(f.object.member, except: f.object)
        f.inputs Delivery.model_name.human(count: 2), icon: "calendar" do
          f.input :delivery_ids,
            as: :check_boxes,
            for: Delivery,
            collection: baskets.map { |b|
              [ "#{l(b.delivery.date, format: :medium)} (#{b.depot.name})", b.delivery_id ]
            },
            disabled: taken_ids,
            label: false,
            hint: t("formtastic.hints.home_delivery_address.deliveries"),
            required: false
        end
      end
    end

    f.actions do
      f.action :submit
      cancel_link f.object.member ? member_path(f.object.member) : members_path
    end
  end

  action_item :new, only: :edit, if: -> { authorized?(:create, HomeDeliveryAddress) } do
    action_link t("active_admin.resources.home_delivery_address.new_model"),
      new_home_delivery_address_path(member_id: resource.member_id),
      icon: "plus"
  end

  action_item :destroy, only: :edit, if: -> { authorized?(:destroy, resource) } do
    action_button t("active_admin.delete_model"), resource_path,
      method: :delete,
      icon: "trash",
      class: "destructive",
      data: { confirm: t("active_admin.delete_confirmation") }
  end

  permit_params do
    permitted = [ :name, :street, :zip, :city, :note, { delivery_ids: [] } ]
    permitted.unshift(:member_id) if action_name == "create"
    permitted
  end

  before_build do |overlay|
    overlay.member_id ||= params[:member_id].presence || smart_referer(:member_id)
  end

  controller do
    def create
      params[:home_delivery_address][:delivery_ids] ||= [] if params[:home_delivery_address]
      create! do |success, failure|
        success.html { redirect_to resource.member }
        failure.html { render :new, status: :unprocessable_entity }
      end
    end

    def update
      params[:home_delivery_address][:delivery_ids] ||= [] if params[:home_delivery_address]
      update! do |success, failure|
        success.html { redirect_to resource.member }
        failure.html { render :edit, status: :unprocessable_entity }
      end
    end

    def destroy
      member = resource.member
      destroy! do |success, failure|
        success.html { redirect_to member }
        failure.html { redirect_to member }
      end
    end
  end
end
