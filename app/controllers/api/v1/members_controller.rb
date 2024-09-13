# frozen_string_literal: true

module API
  module V1
    class MembersController < BaseController
      def create
        @member = Member.new(member_params)

        if @member.save
          Admin.notify!(:new_inscription, member: @member)
          head :created
        else
          Sentry.capture_message("API Member invalid", extra: {
            params: params,
            permitted_params: member_params
          })
          head :unprocessable_entity
        end
      end

      private

      def member_params
        permitted = params.permit(
          :name, :address, :zip, :city, :country_code,
          :emails, :phones,
          :waiting_basket_size_id, :waiting_basket_price_extra,
          :waiting_activity_participations_demanded_annually,
          :waiting_depot_id, :waiting_delivery_cycle_id,
          :waiting_billing_year_division,
          :desired_shares_number,
          :shop_depot_id,
          :profession, :come_from, :note,
          :terms_of_service,
          waiting_alternative_depot_ids: [],
          members_basket_complements_attributes: [
            :basket_complement_id, :quantity
          ])
        permitted[:members_basket_complements_attributes]&.select! { |attrs|
          attrs["quantity"].to_i > 0
        }
        permitted[:waiting_alternative_depot_ids]&.map!(&:presence)&.compact!
        permitted
      end
    end
  end
end
