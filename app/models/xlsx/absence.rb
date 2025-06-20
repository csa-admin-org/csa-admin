# frozen_string_literal: true

module XLSX
  class Absence < Base
    def initialize(absences)
      @absences = absences.includes(:member, :baskets)
      @baskets =
        Basket
          .where(absence: @absences.map(&:id))
          .includes(:member, :delivery, shift_as_source: { target_basket: :delivery })

      build_absences_worksheet
      build_baskets_worksheet
    end

    def filename
      "absences.xlsx"
    end

    private

    def build_absences_worksheet
      add_worksheet ::Absence.model_name.human(count: 2)

      add_column(
        ::Absence.human_attribute_name(:id),
        @absences.map(&:id))
      add_column(
        ::Absence.human_attribute_name(:member_id),
        @absences.map(&:member_id))
      add_column(
        ::Absence.human_attribute_name(:name),
        @absences.map { |absence| absence.member.name })
      add_column(
        ::Absence.human_attribute_name(:started_on),
        @absences.map { |absence| absence.started_on.to_s })
      add_column(
        ::Absence.human_attribute_name(:ended_on),
        @absences.map { |absence| absence.ended_on.to_s })
      add_column(
        ::Basket.model_name.human(count: 2),
        @absences.map { |absence| absence.baskets.size })
      add_column(
        ::Absence.human_attribute_name(:note),
        @absences.map(&:note))
      add_column(
        ::Absence.human_attribute_name(:created_at),
        @absences.map { |absence| absence.created_at.to_s })
    end

    def build_baskets_worksheet
      add_worksheet ::Basket.model_name.human(count: 2)

      add_column(
        ::Basket.human_attribute_name(:id),
        @baskets.map(&:id))
      add_column(
        ::Absence.model_name.human,
        @baskets.map(&:absence_id))
      add_column(
        ::Membership.model_name.human,
        @baskets.map(&:membership_id))
      add_column(
        ::Absence.human_attribute_name(:member_id),
        @baskets.map { |basket| basket.member.id })
      add_column(
        ::Absence.human_attribute_name(:name),
        @baskets.map { |basket| basket.member.name })
      add_column(
        ::Delivery.model_name.human,
        @baskets.map { |basket| basket.delivery.date.to_s })
      add_column(
        ::BasketShift.human_attribute_name(:description),
        @baskets.map { |basket|
          basket.shift_as_source&.description || basket.description
        })
      add_column(
        ::BasketShift.model_name.human,
        @baskets.map { |basket|
          if basket.shift_declined?
            I18n.t("states.basket_shift.declined")
          else
            basket.shift_as_source&.target_basket&.delivery&.date.to_s
          end
        })
    end
  end
end
