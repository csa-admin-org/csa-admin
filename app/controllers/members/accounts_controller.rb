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
    permitted = params
      .require(:member)
      .permit(
        :name,
        :street, :zip, :city, :country_code, :delivery_note,
        :emails, :phones, :language, :theme,
        :different_billing_info,
        :billing_name, :billing_street, :billing_zip, :billing_city,
        :shop_depot_id,
        member_cards_attributes: [ :name, :number, :expires_on ])
    if Current.org.feature?("price_reductions")
      pin_current_reduction_card!(permitted)
    else
      permitted.delete(:member_cards_attributes)
    end
    permitted
  end

  # The account form posts one card. Type and record id come from the current
  # reduction, not from the request, so a posted id cannot retype another card.
  def pin_current_reduction_card!(permitted)
    rows = card_attribute_rows(permitted[:member_cards_attributes])
    card_type = current_member.current_price_reduction&.price_reduction_card
    return permitted.delete(:member_cards_attributes) if rows.empty? || card_type.nil?

    posted = rows.first
    card = current_member.member_card_for(card_type)
    attrs = { "price_reduction_card_id" => card_type.id }
    %w[name number expires_on].each do |key|
      attrs[key] = posted[key] if posted.key?(key)
    end
    attrs["id"] = card.id if card
    permitted[:member_cards_attributes] = { "0" => attrs }
  end

  def card_attribute_rows(cards)
    return [] if cards.blank?

    rows = cards.is_a?(Array) ? cards : cards.values
    rows.compact_blank
  end
end
