# frozen_string_literal: true

ActiveAdmin.register BasketShift do
  menu false
  actions :destroy

  controller do
    def destroy
      destroy! do |success, failure|
        success.html { redirect_to resource.source_basket.membership }
      end
    end
  end
end
