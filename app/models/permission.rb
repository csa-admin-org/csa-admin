# frozen_string_literal: true

class Permission < ApplicationRecord
  include TranslatedAttributes

  RIGHTS = %i[read write].freeze
  SUPERADMIN_ID = 1

  translated_attributes :name, required: true

  has_many :admins

  def self.create_superadmin!
    create!(
      id: SUPERADMIN_ID,
      names: Organization.languages.map { |l|
        [ l, I18n.t("permissions.superadmin.name", locale: l) ]
      }.to_h)
    reset_pk_sequence!
  end

  def self.superadmin
    find(SUPERADMIN_ID)
  end

  def self.features
    superadmin_features + editable_features
  end

  def self.superadmin_features
    %i[
      admin
      basket_complement
      basket_size
      delivery
      permission
      mail_template
    ]
  end

  def self.editable_features
    %i[
      member
      membership
      billing
      depot
      announcement
      newsletter
    ] +
      Current.org.features.map(&:to_sym) - %i[basket_price_extra contact_sharing]
  end

  def rights=(attrs)
    super attrs.select { |feature, right|
      feature.to_sym.in?(self.class.editable_features)
    }.to_h
  end

  def can_write?(feature)
    return true if superadmin?

    right(feature) == :write
  end

  def superadmin?
    id == SUPERADMIN_ID
  end

  def can_destroy?
    !superadmin? && admins.none?
  end

  def can_update?
    !superadmin?
  end

  def right(feature)
    rights[feature.to_s]&.to_sym || :read
  end

  def admins_count
    # Do no count master admin
    if superadmin? && ENV["MASTER_ADMIN_EMAIL"]
      admins.count - 1
    else
      admins.count
    end
  end
end
