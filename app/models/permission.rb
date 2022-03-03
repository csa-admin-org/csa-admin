class Permission < ApplicationRecord
  include TranslatedAttributes

  RIGHTS = %i[read write].freeze
  SUPERADMIN_ID = 1
  SUPERADMIN_FEATURES =

  translated_attributes :name

  has_many :admins

  default_scope { order_by_name }

  def self.create_superadmin!
    create!(
      id: SUPERADMIN_ID,
      names: ACP.languages.map { |l|
        [l, I18n.t("permissions.superadmin.name", locale: l)]
      }.to_h)
    connection.reset_pk_sequence!(table_name)
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
    ] +
      Current.acp.features.map(&:to_sym) - %i[basket_price_extra contact_sharing]
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
end
