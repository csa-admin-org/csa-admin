# frozen_string_literal: true

module Demo::Seeder::Cleanup
  extend ActiveSupport::Concern

  private

  def cleanup_inactive_admins!
    log "Cleaning up inactive admins..."
    ultra_email = ENV["ULTRA_ADMIN_EMAIL"]

    Admin.find_each do |admin|
      next if admin.email == ultra_email

      last_activity = admin.sessions.used.maximum(:last_used_at)
      next unless last_activity && last_activity < Demo::Seeder::ADMIN_INACTIVE_THRESHOLD.ago

      log "Removing inactive admin: #{admin.email}"
      admin.destroy
    end
  end

  def cleanup_custom_permissions!
    log "Cleaning up custom permissions..."
    superadmin = Permission.superadmin
    Admin.where.not(permission_id: Permission::SUPERADMIN_ID).update_all(permission_id: superadmin.id)
    Permission.where.not(id: Permission::SUPERADMIN_ID).delete_all
  end

  def clear_transactional_data!
    log "Clearing transactional data..."
    without_foreign_keys { delete_transactional_records! }
  end

  def clear_reference_data!
    log "Clearing reference data..."
    without_foreign_keys { delete_reference_records! }
  end

  def reset_primary_key_sequences!
    log "Resetting primary key sequences..."
    ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence")
  end

  def without_foreign_keys
    ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF")
    yield
  ensure
    ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
  end

  def delete_transactional_records!
    purge_non_logo_attachments!
    Current.org.logo.variant(resize_to_limit: [ 330, 330 ]).processed.download

    ::Shop::OrderItem.delete_all
    ::Shop::Order.delete_all
    MailDelivery::Email.delete_all
    MailDelivery.delete_all
    ActionText::RichText.where(record_type: "Newsletter::Block").delete_all
    Newsletter::Block.delete_all
    Newsletter.delete_all
    ActivityParticipation.delete_all
    Activity.delete_all
    BasketShift.delete_all
    Absence.delete_all
    Payment.delete_all
    InvoiceItem.delete_all
    Invoice.delete_all
    BasketsBasketComplement.delete_all
    Basket.delete_all
    SEPAMandate.delete_all
    BiddingRound::Pledge.delete_all
    ActionText::RichText.where(record_type: "BiddingRound").delete_all
    BiddingRound.delete_all
    MembershipsBasketComplement.delete_all
    MembersBasketComplement.delete_all
    Membership.delete_all
    Session.where.not(member_id: nil).delete_all
    Member.delete_all
    EmailSuppression.delete_all
    Audit.delete_all
  end

  def purge_non_logo_attachments!
    org_logo_blob_id = ::Organization.instance.logo.blob&.id
    org_logo_variant_record_ids =
      org_logo_blob_id ? ActiveStorage::VariantRecord.where(blob_id: org_logo_blob_id).pluck(:id) : []

    ActiveStorage::Attachment
      .where.not(record_type: "Organization", name: "logo")
      .where.not(record_type: "ActiveStorage::VariantRecord", record_id: org_logo_variant_record_ids)
      .find_each(&:purge)
  end

  def delete_reference_records!
    connection = ActiveRecord::Base.connection
    connection.execute("DELETE FROM basket_contents_depots")
    BasketContent.delete_all
    BasketContent::Product.delete_all
    ForcedDelivery.delete_all
    Delivery.delete_all
    DeliveryCycle::Period.delete_all
    connection.execute("DELETE FROM basket_complements_deliveries")
    connection.execute("DELETE FROM delivery_cycles_depots")
    BasketComplement.delete_all
    Depot.delete_all
    BasketSize.delete_all
    DeliveryCycle.delete_all
    ActivityPreset.delete_all
    connection.execute("DELETE FROM shop_products_tags")
    connection.execute("DELETE FROM shop_products_special_deliveries")
    ::Shop::ProductVariant.delete_all
    ::Shop::Product.delete_all
    ::Shop::Producer.delete_all
    ::Shop::Tag.delete_all
    ::Shop::SpecialDelivery.delete_all
    MailTemplate.delete_all
    Newsletter::Template.delete_all
  end
end
