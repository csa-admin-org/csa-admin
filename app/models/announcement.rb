# frozen_string_literal: true

class Announcement < ApplicationRecord
  include TranslatedAttributes

  translated_attributes :text

  validates :depot_ids, presence: true
  I18n.available_locales.each do |locale|
    validates "text_#{locale}",
      presence: true,
      length: { maximum: 140 },
      if: -> { Current.org.languages.include?(locale.to_s) }
  end
  validate :must_be_unique_per_depot_and_delivery

  scope :depots_eq, ->(id) {
    where("EXISTS (SELECT 1 FROM json_each(depot_ids) WHERE json_each.value = ?)", id.to_i)
  }
  scope :deliveries_eq, ->(id) {
    where("EXISTS (SELECT 1 FROM json_each(delivery_ids) WHERE json_each.value = ?)", id.to_i)
  }

  def self.for(delivery, depot)
    deliveries_eq(delivery.id).depots_eq(depot.id).first
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[depots_eq deliveries_eq]
  end

  def depot_ids=(ids)
    super ids.map(&:presence).compact.map(&:to_i).sort
  end

  def depots
    @depots ||= Depot.where(id: depot_ids)
  end

  def delivery_ids=(ids)
    super ids.map(&:presence).compact.map(&:to_i).sort
  end

  def deliveries
    @deliveries ||= Delivery.where(id: delivery_ids)
  end

  def coming_deliveries
    @coming_deliveries ||= deliveries.coming
  end

  private

  def must_be_unique_per_depot_and_delivery
    depots.each do |depot|
      deliveries.each do |delivery|
        announcement = self.class.for(delivery, depot)
        if announcement && announcement.id != id
          errors.add(
            :base,
            I18n.t("errors.messages.announcement_not_unique",
              delivery: delivery.display_name,
              depot: depot.name,
              other_text: announcement.text.truncate(30)))
        end
      end
    end
  end
end
