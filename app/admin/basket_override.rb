# frozen_string_literal: true

ActiveAdmin.register BasketOverride do
  menu false
  actions :destroy

  controller do
    def destroy
      membership = resource.membership
      resource.destroy!
      redirect_to membership
    end
  end
end
