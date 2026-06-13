# frozen_string_literal: true

module Member::Auditing
  extend ActiveSupport::Concern

  module WaitingRequestTracking
    include Auditable::BasketComplementsTracking

    def members_basket_complements_attributes=(*args)
      track_waiting_basket_complements_change
      super
    end

    def waiting_basket_complement_ids=(*args)
      track_waiting_basket_complements_change
      super
    end

    def waiting_alternative_depot_ids=(*args)
      @tracked_waiting_alternative_depot_ids = waiting_alternative_depot_ids
      super
    end

    private

    def audited_nested_changes
      {}.tap do |changes|
        if change = basket_complements_change(:waiting_basket_complements, members_basket_complements)
          changes["waiting_basket_complements"] = change
        end
        if change = waiting_alternative_depot_ids_change
          changes["waiting_alternative_depot_ids"] = change
        end
      end
    end

    def track_waiting_basket_complements_change
      track_basket_complements_change(:waiting_basket_complements, members_basket_complements)
    end

    def waiting_alternative_depot_ids_change
      return unless @tracked_waiting_alternative_depot_ids

      before_ids = @tracked_waiting_alternative_depot_ids.map(&:to_i).sort
      after_ids = waiting_alternative_depot_ids.map(&:to_i).sort
      return if before_ids == after_ids

      [ before_ids, after_ids ]
    end
  end

  included do
    include Auditable
    prepend WaitingRequestTracking

    audited_attributes \
      :state, :name, :emails, :billing_email, :phones, :contact_sharing, \
      :street, :zip, :city, :country_code, \
      :billing_name, :billing_street, :billing_city, :billing_zip, :sepa_disabled_at, \
      :profession, :come_from, :note, :delivery_note, :food_note, \
      :annual_fee, :shares_info, :existing_shares_number, :required_shares_number, :desired_shares_number, \
      :shop_depot_id, :shop_delivery_cycle_id, :salary_basket, \
      :waiting_started_at, :waiting_basket_size_id, :waiting_depot_id, :waiting_delivery_cycle_id, \
      :waiting_basket_price_extra, :waiting_activity_participations_demanded_annually, \
      :waiting_billing_year_division
  end
end
