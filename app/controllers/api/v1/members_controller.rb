# frozen_string_literal: true

module API
  module V1
    class MembersController < BaseController
      def create
        attributes = member_params
        member = Member.new(attributes)
        member.public_create = true
        registration = MemberRegistration.new(member, attributes)

        if registration.save
          head :created
        else
          render json: { errors: registration.member.errors.messages }, status: :unprocessable_entity
        end
      end

      private

      def member_params
        permitted = params.permit(
          :name, :street, :zip, :city, :country_code,
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
        normalize_members_basket_complements(permitted)
        normalize_waiting_alternative_depots(permitted)
        normalize_desired_shares_number(permitted)
        permitted
      end

      def normalize_members_basket_complements(permitted)
        permitted[:members_basket_complements_attributes]&.select! { |attrs|
          attrs["quantity"].to_i > 0
        }
      end

      def normalize_waiting_alternative_depots(permitted)
        permitted[:waiting_alternative_depot_ids]&.map!(&:presence)&.compact!
      end

      def normalize_desired_shares_number(permitted)
        unless Current.org.feature?("shares")
          permitted.delete(:desired_shares_number)
          return
        end

        return if permitted[:desired_shares_number].present?

        permitted[:desired_shares_number] = default_desired_shares_number(permitted)
      end

      def default_desired_shares_number(permitted)
        waiting_basket_size(permitted)&.shares_number || Current.org.shares_number || 0
      end

      def waiting_basket_size(permitted)
        BasketSize.find_by(id: permitted[:waiting_basket_size_id])
      end
    end
  end
end
