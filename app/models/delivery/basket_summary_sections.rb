# frozen_string_literal: true

class Delivery::BasketSummarySections
  Row = Data.define(:title, :depot_ids)
  Section = Data.define(:dimension, :rows) do
    def partition_signature
      rows.map { |row| row.depot_ids.sort }.sort
    end
  end

  def initialize(delivery, depots: nil)
    @delivery = delivery
    @depots = depots ? Array(depots) : @delivery.used_depots.includes(:group).to_a
  end

  def sections
    @sections ||= begin
      depot_group_section = build_depot_group_section
      price_section = build_price_section

      [ depot_group_section, price_section ]
        .compact
        .reject { |section| redundant?(section, depot_group_section) }
        .freeze
    end
  end

  private

  def build_depot_group_section
    return unless @depots.any?(&:group_id)

    depots_by_group_id = @depots.group_by(&:group_id)
    rows = DepotGroup
      .where(id: depots_by_group_id.keys.compact)
      .member_ordered
      .map { |group|
        build_row(group.display_name, depots_by_group_id[group.id])
      }

    if depots_by_group_id[nil].present?
      rows << build_row(I18n.t("delivery.ungrouped_depots"), depots_by_group_id[nil])
    end
    return if rows.one?

    Section.new(dimension: :depot_group, rows: rows)
  end

  def build_price_section
    free_depots = @depots.select(&:free?)
    paid_depots = @depots.select(&:paid?)
    return if free_depots.empty? || paid_depots.empty?

    Section.new(
      dimension: :price,
      rows: [
        build_row(I18n.t("delivery.free_depots"), free_depots),
        build_row(I18n.t("delivery.paid_depots"), paid_depots)
      ])
  end

  def build_row(title, depots)
    Row.new(title: title, depot_ids: depots.map(&:id))
  end

  def redundant?(section, depot_group_section)
    return false unless section&.dimension == :price
    return false unless depot_group_section

    section.partition_signature == depot_group_section.partition_signature
  end
end
