# frozen_string_literal: true

class Members::AccountsController < Members::BaseController
  def show
  end

  def edit
  end

  def update
    if current_member.update(member_params)
      redirect_to members_account_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def member_params
    params
      .require(:member)
      .permit(
        :name,
        :street, :zip, :city, :country_code,
        :emails, :phones, :language, :theme,
        :different_billing_info,
        :billing_name, :billing_street, :billing_zip, :billing_city,
        :shop_depot_id)
  end
end
