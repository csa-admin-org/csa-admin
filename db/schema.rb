# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_06_06_112848) do
  create_table "absences", force: :cascade do |t|
    t.datetime "created_at"
    t.date "ended_on"
    t.bigint "member_id"
    t.text "note"
    t.bigint "session_id"
    t.date "started_on"
    t.datetime "updated_at"
    t.index ["member_id"], name: "index_absences_on_member_id"
    t.index ["session_id"], name: "index_absences_on_session_id"
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_admin_comments", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type", limit: 255
    t.text "body"
    t.datetime "created_at"
    t.string "namespace", limit: 255
    t.string "resource_id", limit: 255, null: false
    t.string "resource_type", limit: 255, null: false
    t.datetime "updated_at"
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.json "descriptions", default: {}, null: false
    t.string "end_time", null: false
    t.integer "participants_limit"
    t.json "place_urls", default: {}, null: false
    t.json "places", default: {}, null: false
    t.string "start_time", null: false
    t.json "titles", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_activities_on_date"
    t.index ["start_time"], name: "index_activities_on_start_time"
  end

  create_table "activity_participations", force: :cascade do |t|
    t.bigint "activity_id", null: false
    t.datetime "admins_notified_at"
    t.string "carpooling_city"
    t.string "carpooling_phone"
    t.datetime "created_at", null: false
    t.datetime "latest_reminder_sent_at"
    t.bigint "member_id", null: false
    t.text "note"
    t.integer "participants_count", default: 1, null: false
    t.datetime "rejected_at"
    t.datetime "review_sent_at"
    t.bigint "session_id"
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.datetime "validated_at"
    t.bigint "validator_id"
    t.index ["activity_id"], name: "index_activity_participations_on_activity_id"
    t.index ["member_id"], name: "index_activity_participations_on_member_id"
    t.index ["session_id"], name: "index_activity_participations_on_session_id"
    t.index ["state"], name: "index_activity_participations_on_state"
    t.index ["validator_id"], name: "index_activity_participations_on_validator_id"
  end

  create_table "activity_presets", force: :cascade do |t|
    t.json "place_urls", default: {}, null: false
    t.json "places", default: {}, null: false
    t.json "titles", default: {}, null: false
    t.index ["places", "titles"], name: "index_activity_presets_on_places_and_titles", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.datetime "created_at"
    t.string "email", limit: 255, default: "", null: false
    t.string "language", default: "fr", null: false
    t.string "latest_update_read"
    t.string "name", null: false
    t.json "notifications", default: [], null: false
    t.bigint "permission_id", null: false
    t.datetime "updated_at"
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["permission_id"], name: "index_admins_on_permission_id"
    t.check_constraint "JSON_TYPE(notifications) = 'array'", name: "admins_notifications_is_array"
  end

  create_table "announcements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "delivery_ids", default: [], null: false
    t.json "depot_ids", default: [], null: false
    t.json "texts", default: {}, null: false
    t.datetime "updated_at", null: false
    t.check_constraint "JSON_TYPE(delivery_ids) = 'array'", name: "announcements_delivery_ids_is_array"
    t.check_constraint "JSON_TYPE(depot_ids) = 'array'", name: "announcements_depot_ids_is_array"
  end

  create_table "attachments", force: :cascade do |t|
    t.integer "attachable_id", null: false
    t.string "attachable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attachable_type", "attachable_id"], name: "index_attachments_on_attachable"
  end

  create_table "audits", force: :cascade do |t|
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.json "audited_changes", default: {}, null: false
    t.datetime "created_at", null: false
    t.bigint "session_id"
    t.datetime "updated_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audits_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["session_id"], name: "index_audits_on_session_id"
  end

  create_table "basket_complements", force: :cascade do |t|
    t.integer "activity_participations_demanded_annually", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.json "form_details", default: {}, null: false
    t.integer "member_order_priority", default: 1, null: false
    t.json "names", default: {}, null: false
    t.decimal "price", precision: 8, scale: 3, default: "0.0", null: false
    t.json "public_names", default: {}, null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
    t.index ["discarded_at"], name: "index_basket_complements_on_discarded_at"
    t.index ["visible"], name: "index_basket_complements_on_visible"
  end

  create_table "basket_complements_deliveries", force: :cascade do |t|
    t.bigint "basket_complement_id", null: false
    t.bigint "delivery_id", null: false
    t.index ["basket_complement_id", "delivery_id"], name: "basket_complements_deliveries_unique_index", unique: true
  end

  create_table "basket_content_products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "names", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "basket_contents", force: :cascade do |t|
    t.json "basket_percentages", default: [], null: false
    t.json "basket_quantities", default: [], null: false
    t.json "basket_size_ids", default: [], null: false
    t.json "baskets_counts", default: [], null: false
    t.datetime "created_at", null: false
    t.bigint "delivery_id", null: false
    t.string "distribution_mode", default: "automatic", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 8, scale: 2, null: false
    t.decimal "surplus_quantity", precision: 8, scale: 2, default: "0.0", null: false
    t.string "unit", null: false
    t.decimal "unit_price", precision: 8, scale: 2
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_basket_contents_on_delivery_id"
    t.index ["product_id"], name: "index_basket_contents_on_product_id"
    t.check_constraint "JSON_TYPE(basket_percentages) = 'array'", name: "basket_contents_basket_percentages_is_array"
    t.check_constraint "JSON_TYPE(basket_quantities) = 'array'", name: "basket_contents_basket_quantities_is_array"
    t.check_constraint "JSON_TYPE(basket_size_ids) = 'array'", name: "basket_contents_basket_size_ids_is_array"
    t.check_constraint "JSON_TYPE(baskets_counts) = 'array'", name: "basket_contents_baskets_counts_is_array"
  end

  create_table "basket_contents_depots", id: false, force: :cascade do |t|
    t.bigint "basket_content_id", null: false
    t.bigint "depot_id", null: false
    t.index ["basket_content_id", "depot_id"], name: "index_basket_contents_depots_unique", unique: true
    t.index ["basket_content_id"], name: "index_basket_contents_depots_on_basket_content_id"
    t.index ["depot_id"], name: "index_basket_contents_depots_on_depot_id"
  end

  create_table "basket_shifts", force: :cascade do |t|
    t.integer "absence_id", null: false
    t.datetime "created_at", null: false
    t.json "quantities", default: {}, null: false
    t.integer "source_basket_id", null: false
    t.integer "target_basket_id", null: false
    t.datetime "updated_at", null: false
    t.index ["absence_id", "source_basket_id"], name: "index_basket_shifts_on_absence_id_and_source_basket_id", unique: true
    t.index ["absence_id"], name: "index_basket_shifts_on_absence_id"
    t.index ["source_basket_id"], name: "index_basket_shifts_on_source_basket_id"
    t.index ["target_basket_id"], name: "index_basket_shifts_on_target_basket_id"
  end

  create_table "basket_sizes", force: :cascade do |t|
    t.integer "activity_participations_demanded_annually", default: 0, null: false
    t.datetime "created_at"
    t.bigint "delivery_cycle_id"
    t.datetime "discarded_at"
    t.json "form_details", default: {}, null: false
    t.integer "member_order_priority", default: 1, null: false
    t.json "names", default: {}, null: false
    t.decimal "price", precision: 8, scale: 3, default: "0.0", null: false
    t.json "public_names", default: {}, null: false
    t.integer "shares_number"
    t.datetime "updated_at"
    t.boolean "visible", default: true, null: false
    t.index ["delivery_cycle_id"], name: "index_basket_sizes_on_delivery_cycle_id"
    t.index ["discarded_at"], name: "index_basket_sizes_on_discarded_at"
    t.index ["visible"], name: "index_basket_sizes_on_visible"
  end

  create_table "baskets", force: :cascade do |t|
    t.bigint "absence_id"
    t.decimal "basket_price", precision: 8, scale: 3, null: false
    t.bigint "basket_size_id", null: false
    t.boolean "billable", default: true, null: false
    t.decimal "calculated_price_extra", precision: 8, scale: 3, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.decimal "delivery_cycle_price", precision: 8, scale: 2, null: false
    t.bigint "delivery_id", null: false
    t.bigint "depot_id", null: false
    t.decimal "depot_price", precision: 8, scale: 2, null: false
    t.bigint "membership_id", null: false
    t.decimal "price_extra", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "shift_declined_at"
    t.string "state", default: "normal", null: false
    t.datetime "updated_at", null: false
    t.index ["absence_id"], name: "index_baskets_on_absence_id"
    t.index ["basket_size_id"], name: "index_baskets_on_basket_size_id"
    t.index ["delivery_id", "membership_id"], name: "index_baskets_on_delivery_id_and_membership_id", unique: true
    t.index ["delivery_id"], name: "index_baskets_on_delivery_id"
    t.index ["depot_id"], name: "index_baskets_on_depot_id"
    t.index ["membership_id"], name: "index_baskets_on_membership_id"
  end

  create_table "baskets_basket_complements", force: :cascade do |t|
    t.bigint "basket_complement_id", null: false
    t.bigint "basket_id", null: false
    t.datetime "created_at", null: false
    t.decimal "price", precision: 8, scale: 3, null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["basket_complement_id", "basket_id"], name: "baskets_basket_complements_unique_index", unique: true
  end

  create_table "billing_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "deliveries", force: :cascade do |t|
    t.json "basket_content_avg_prices", default: {}
    t.datetime "created_at"
    t.date "date", null: false
    t.text "note"
    t.integer "number", default: 0, null: false
    t.json "shop_closed_for_depot_ids", default: []
    t.boolean "shop_open", default: true
    t.datetime "updated_at"
    t.index ["date"], name: "index_deliveries_on_date", unique: true
    t.index ["shop_open"], name: "index_deliveries_on_shop_open"
    t.check_constraint "JSON_TYPE(shop_closed_for_depot_ids) = 'array'", name: "deliveries_shop_closed_for_depot_ids_is_array"
  end

  create_table "delivery_cycles", force: :cascade do |t|
    t.integer "absences_included_annually", default: 0, null: false
    t.datetime "created_at", null: false
    t.json "deliveries_counts", default: {}, null: false
    t.datetime "discarded_at"
    t.json "form_details", default: {}, null: false
    t.json "invoice_names", default: {}, null: false
    t.integer "member_order_priority", default: 1, null: false
    t.integer "minimum_gap_in_days"
    t.json "months", default: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], null: false
    t.json "names", default: {}, null: false
    t.decimal "price", precision: 8, scale: 2, default: "0.0", null: false
    t.json "public_names", default: {}, null: false
    t.integer "results", default: 0, null: false
    t.datetime "updated_at", null: false
    t.json "wdays", default: [0, 1, 2, 3, 4, 5, 6], null: false
    t.integer "week_numbers", default: 0, null: false
    t.index ["discarded_at"], name: "index_delivery_cycles_on_discarded_at"
    t.check_constraint "JSON_TYPE(months) = 'array'", name: "delivery_cycles_months_is_array"
    t.check_constraint "JSON_TYPE(wdays) = 'array'", name: "delivery_cycles_wdays_is_array"
  end

  create_table "delivery_cycles_depots", force: :cascade do |t|
    t.bigint "delivery_cycle_id", null: false
    t.bigint "depot_id", null: false
    t.index ["depot_id", "delivery_cycle_id"], name: "index_delivery_cycles_depots_on_depot_id_and_delivery_cycle_id", unique: true
  end

  create_table "depot_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "member_order_priority", default: 1, null: false
    t.json "names", default: {}, null: false
    t.json "public_names", default: {}, null: false
    t.datetime "updated_at", null: false
  end

  create_table "depots", force: :cascade do |t|
    t.string "address", limit: 255
    t.string "address_name"
    t.string "city", limit: 255
    t.string "contact_name"
    t.datetime "created_at"
    t.string "delivery_sheets_mode", default: "signature", null: false
    t.datetime "discarded_at"
    t.string "emails"
    t.json "form_details", default: {}, null: false
    t.bigint "group_id"
    t.string "language", default: "fr", null: false
    t.json "member_ids_position", default: []
    t.integer "member_order_priority", default: 1, null: false
    t.json "names", default: {}, null: false
    t.text "note"
    t.string "phones"
    t.integer "position"
    t.decimal "price", precision: 8, scale: 2, null: false
    t.json "public_names", default: {}, null: false
    t.datetime "updated_at"
    t.boolean "visible", default: true, null: false
    t.string "zip", limit: 255
    t.index ["discarded_at"], name: "index_depots_on_discarded_at"
    t.index ["group_id"], name: "index_depots_on_group_id"
    t.index ["visible"], name: "index_depots_on_visible"
    t.check_constraint "JSON_TYPE(member_ids_position) = 'array'", name: "depots_member_ids_position_is_array"
  end

  create_table "email_suppressions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "email"
    t.string "origin"
    t.string "reason"
    t.string "stream_id"
    t.datetime "unsuppressed_at"
    t.index ["stream_id", "email", "reason", "origin", "created_at"], name: "email_suppressions_unique_index", unique: true
  end

  create_table "invoice_items", force: :cascade do |t|
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.bigint "invoice_id"
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.decimal "amount_before_percentage", precision: 8, scale: 2
    t.decimal "amount_percentage", precision: 8, scale: 2
    t.decimal "annual_fee", precision: 8, scale: 2
    t.datetime "canceled_at"
    t.datetime "created_at"
    t.date "date", null: false
    t.bigint "entity_id"
    t.string "entity_type", null: false
    t.bigint "member_id", null: false
    t.decimal "memberships_amount", precision: 8, scale: 2
    t.string "memberships_amount_description"
    t.integer "missing_activity_participations_count"
    t.integer "missing_activity_participations_fiscal_year"
    t.datetime "overdue_notice_sent_at"
    t.integer "overdue_notices_count", default: 0, null: false
    t.datetime "overpaid_notification_sent_at"
    t.decimal "paid_amount", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "paid_memberships_amount", precision: 8, scale: 2
    t.decimal "remaining_memberships_amount", precision: 8, scale: 2
    t.datetime "sent_at"
    t.json "sepa_metadata", default: {}, null: false
    t.integer "shares_number"
    t.datetime "stamped_at"
    t.string "state", default: "processing", null: false
    t.datetime "updated_at"
    t.decimal "vat_amount", precision: 8, scale: 2
    t.decimal "vat_rate", precision: 8, scale: 2
    t.index ["entity_type", "entity_id"], name: "index_invoices_on_entity_type_and_entity_id"
    t.index ["member_id"], name: "index_invoices_on_member_id"
    t.index ["state"], name: "index_invoices_on_state"
  end

  create_table "mail_templates", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.json "contents", default: {}, null: false
    t.datetime "created_at", null: false
    t.json "delivery_cycle_ids"
    t.json "subjects", default: {}, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_mail_templates_on_title", unique: true
    t.check_constraint "JSON_TYPE(delivery_cycle_ids) = 'array'", name: "mail_templates_delivery_cycle_ids_is_array"
  end

  create_table "members", force: :cascade do |t|
    t.datetime "activated_at"
    t.string "address", limit: 255
    t.decimal "annual_fee", precision: 8, scale: 2
    t.string "billing_address"
    t.string "billing_city"
    t.string "billing_email"
    t.string "billing_name"
    t.string "billing_zip"
    t.string "city", limit: 255
    t.text "come_from"
    t.boolean "contact_sharing", default: false, null: false
    t.string "country_code", limit: 2
    t.datetime "created_at"
    t.string "delivery_note"
    t.integer "desired_shares_number", default: 0, null: false
    t.string "emails"
    t.integer "existing_shares_number", default: 0, null: false
    t.datetime "final_basket_sent_at"
    t.text "food_note"
    t.string "iban"
    t.datetime "initial_basket_sent_at"
    t.string "language", default: "fr", null: false
    t.integer "memberships_count", default: 0, null: false
    t.string "name", null: false
    t.text "note"
    t.string "phones", limit: 255
    t.string "profession"
    t.integer "required_shares_number"
    t.boolean "salary_basket", default: false
    t.string "sepa_mandate_id"
    t.date "sepa_mandate_signed_on"
    t.string "shares_info"
    t.bigint "shop_depot_id"
    t.string "state", default: "pending", null: false
    t.integer "trial_baskets_count", null: false
    t.datetime "updated_at"
    t.datetime "validated_at"
    t.bigint "validator_id"
    t.integer "waiting_activity_participations_demanded_annually"
    t.decimal "waiting_basket_price_extra", precision: 8, scale: 2
    t.bigint "waiting_basket_size_id"
    t.integer "waiting_billing_year_division"
    t.bigint "waiting_delivery_cycle_id"
    t.bigint "waiting_depot_id"
    t.datetime "waiting_started_at"
    t.string "zip", limit: 255
    t.index ["sepa_mandate_id"], name: "index_members_on_sepa_mandate_id", unique: true
    t.index ["shop_depot_id"], name: "index_members_on_shop_depot_id"
    t.index ["state"], name: "index_members_on_state"
    t.index ["validator_id"], name: "index_members_on_validator_id"
    t.index ["waiting_basket_size_id"], name: "index_members_on_waiting_basket_size_id"
    t.index ["waiting_delivery_cycle_id"], name: "index_members_on_waiting_delivery_cycle_id"
    t.index ["waiting_depot_id"], name: "index_members_on_waiting_depot_id"
    t.index ["waiting_started_at"], name: "index_members_on_waiting_started_at"
  end

  create_table "members_basket_complements", force: :cascade do |t|
    t.bigint "basket_complement_id", null: false
    t.datetime "created_at"
    t.bigint "member_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at"
    t.index ["basket_complement_id", "member_id"], name: "members_basket_complements_unique_index", unique: true
  end

  create_table "members_waiting_alternative_depots", id: false, force: :cascade do |t|
    t.bigint "depot_id", null: false
    t.bigint "member_id", null: false
    t.index ["depot_id"], name: "index_members_waiting_alternative_depots_on_depot_id"
    t.index ["member_id"], name: "index_members_waiting_alternative_depots_on_member_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "absences_included", default: 0, null: false
    t.integer "absences_included_annually", null: false
    t.integer "activity_participations_accepted", default: 0, null: false
    t.decimal "activity_participations_annual_price_change", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "activity_participations_demanded", default: 0, null: false
    t.integer "activity_participations_demanded_annually", null: false
    t.decimal "basket_complements_annual_price_change", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "basket_price", precision: 8, scale: 3, null: false
    t.decimal "basket_price_extra", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "basket_quantity", default: 1, null: false
    t.bigint "basket_size_id", null: false
    t.decimal "baskets_annual_price_change", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "baskets_count", default: 0, null: false
    t.integer "billing_year_division", default: 1, null: false
    t.datetime "created_at"
    t.bigint "delivery_cycle_id", null: false
    t.decimal "delivery_cycle_price", precision: 8, scale: 2, null: false
    t.bigint "depot_id", null: false
    t.decimal "depot_price", precision: 8, scale: 3, null: false
    t.date "ended_on", null: false
    t.datetime "first_basket_sent_at"
    t.decimal "invoices_amount", precision: 8, scale: 2
    t.datetime "last_basket_sent_at"
    t.datetime "last_trial_basket_sent_at"
    t.bigint "member_id", null: false
    t.integer "past_baskets_count", default: 0, null: false
    t.decimal "price", precision: 8, scale: 2
    t.integer "remaining_trial_baskets_count", default: 0, null: false
    t.boolean "renew", default: false, null: false
    t.decimal "renewal_annual_fee", precision: 8, scale: 2
    t.text "renewal_note"
    t.datetime "renewal_opened_at"
    t.datetime "renewal_reminder_sent_at"
    t.datetime "renewed_at"
    t.date "started_on", null: false
    t.integer "trial_baskets_count", default: 0
    t.datetime "updated_at"
    t.index ["basket_size_id"], name: "index_memberships_on_basket_size_id"
    t.index ["delivery_cycle_id"], name: "index_memberships_on_delivery_cycle_id"
    t.index ["depot_id"], name: "index_memberships_on_depot_id"
    t.index ["ended_on"], name: "index_memberships_on_ended_on"
    t.index ["member_id"], name: "index_memberships_on_member_id"
    t.index ["started_on"], name: "index_memberships_on_started_on"
  end

  create_table "memberships_basket_complements", force: :cascade do |t|
    t.bigint "basket_complement_id", null: false
    t.datetime "created_at", null: false
    t.bigint "delivery_cycle_id"
    t.bigint "membership_id", null: false
    t.decimal "price", precision: 8, scale: 3, null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["basket_complement_id", "membership_id"], name: "memberships_basket_complements_unique_index", unique: true
    t.index ["delivery_cycle_id"], name: "index_memberships_basket_complements_on_delivery_cycle_id"
  end

  create_table "newsletter_blocks", force: :cascade do |t|
    t.string "block_id", null: false
    t.datetime "created_at", null: false
    t.bigint "newsletter_id", null: false
    t.datetime "updated_at", null: false
    t.index ["newsletter_id", "block_id"], name: "index_newsletter_blocks_on_newsletter_id_and_block_id", unique: true
    t.index ["newsletter_id"], name: "index_newsletter_blocks_on_newsletter_id"
  end

  create_table "newsletter_deliveries", force: :cascade do |t|
    t.string "bounce_description"
    t.string "bounce_type"
    t.integer "bounce_type_code"
    t.datetime "bounced_at"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "email"
    t.json "email_suppression_ids", default: [], null: false
    t.json "email_suppression_reasons", default: [], null: false
    t.bigint "member_id", null: false
    t.bigint "newsletter_id", null: false
    t.text "postmark_details"
    t.string "postmark_message_id"
    t.datetime "processed_at"
    t.string "state", default: "processing", null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_newsletter_deliveries_on_member_id"
    t.index ["newsletter_id", "member_id", "email"], name: "idx_on_newsletter_id_member_id_email_00311dbc8c", unique: true
    t.index ["newsletter_id"], name: "index_newsletter_deliveries_on_newsletter_id"
    t.index ["state"], name: "index_newsletter_deliveries_on_state"
    t.check_constraint "JSON_TYPE(email_suppression_ids) = 'array'", name: "newsletter_deliveries_email_suppression_ids_is_array"
    t.check_constraint "JSON_TYPE(email_suppression_reasons) = 'array'", name: "newsletter_deliveries_email_suppression_reasons_is_array"
  end

  create_table "newsletter_segments", force: :cascade do |t|
    t.json "basket_complement_ids", default: [], null: false
    t.json "basket_size_ids", default: [], null: false
    t.integer "billing_year_division"
    t.integer "coming_deliveries_in_days"
    t.datetime "created_at", null: false
    t.json "delivery_cycle_ids", default: [], null: false
    t.json "depot_ids", default: [], null: false
    t.boolean "first_membership"
    t.string "renewal_state"
    t.json "titles", default: {}, null: false
    t.datetime "updated_at", null: false
    t.check_constraint "JSON_TYPE(basket_complement_ids) = 'array'", name: "newsletter_segments_basket_complement_ids_is_array"
    t.check_constraint "JSON_TYPE(basket_size_ids) = 'array'", name: "newsletter_segments_basket_size_ids_is_array"
    t.check_constraint "JSON_TYPE(delivery_cycle_ids) = 'array'", name: "newsletter_segments_delivery_cycle_ids_is_array"
    t.check_constraint "JSON_TYPE(depot_ids) = 'array'", name: "newsletter_segments_basket_complement_ids_is_array"
  end

  create_table "newsletter_templates", force: :cascade do |t|
    t.json "contents", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_newsletter_templates_on_title", unique: true
  end

  create_table "newsletters", force: :cascade do |t|
    t.string "audience", null: false
    t.json "audience_names", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "from"
    t.json "liquid_data_preview_yamls", default: {}, null: false
    t.bigint "newsletter_template_id", null: false
    t.datetime "scheduled_at"
    t.datetime "sent_at"
    t.json "signatures", default: {}, null: false
    t.json "subjects", default: {}, null: false
    t.json "template_contents", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["newsletter_template_id"], name: "index_newsletters_on_newsletter_template_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.boolean "absence_extra_text_only", default: false, null: false
    t.integer "absence_notice_period_in_days", default: 7, null: false
    t.boolean "absences_billed", default: true, null: false
    t.integer "activity_availability_limit_in_days", default: 3, null: false
    t.string "activity_i18n_scope", default: "halfday_work", null: false
    t.integer "activity_participation_deletion_deadline_in_days"
    t.text "activity_participations_demanded_logic", null: false
    t.json "activity_participations_form_details", default: {}, null: false
    t.integer "activity_participations_form_max"
    t.integer "activity_participations_form_min"
    t.integer "activity_participations_form_step", default: 1, null: false
    t.string "activity_phone"
    t.decimal "activity_price", precision: 8, scale: 2, default: "0.0", null: false
    t.boolean "allow_alternative_depots", default: false, null: false
    t.decimal "annual_fee", precision: 8, scale: 2
    t.boolean "annual_fee_member_form", default: false, null: false
    t.boolean "annual_fee_support_member_only", default: false, null: false
    t.string "bank_reference"
    t.string "basket_complements_member_order_mode", default: "deliveries_count_desc", null: false
    t.text "basket_price_extra_dynamic_pricing"
    t.json "basket_price_extra_label_details", default: {}, null: false
    t.json "basket_price_extra_labels", default: {}, null: false
    t.json "basket_price_extra_public_titles", default: {}, null: false
    t.json "basket_price_extra_texts", default: {}, null: false
    t.json "basket_price_extra_titles", default: {}, null: false
    t.json "basket_price_extras", default: [], null: false
    t.integer "basket_shift_deadline_in_weeks", default: 4
    t.integer "basket_shifts_annually", default: 0
    t.string "basket_sizes_member_order_mode", default: "price_desc", null: false
    t.integer "basket_update_limit_in_days", default: 0, null: false
    t.boolean "billing_ends_on_last_delivery_fy_month", default: false, null: false
    t.boolean "billing_starts_after_first_delivery", default: true, null: false
    t.json "billing_year_divisions", default: [], null: false
    t.json "charter_urls", default: {}, null: false
    t.string "country_code", limit: 2, default: "CH", null: false
    t.datetime "created_at", null: false
    t.string "creditor_address", limit: 70
    t.string "creditor_city", limit: 35
    t.string "creditor_name", limit: 70
    t.string "creditor_zip", limit: 16
    t.string "currency_code", limit: 3, default: "CHF"
    t.string "delivery_cycles_member_order_mode", default: "deliveries_count_desc", null: false
    t.json "delivery_pdf_footers", default: {}, null: false
    t.string "delivery_pdf_member_info", default: "none", null: false
    t.string "depots_member_order_mode", default: "price_asc", null: false
    t.string "email"
    t.string "email_default_from", null: false
    t.json "email_footers", default: {}, null: false
    t.json "email_notifications", default: [], null: false
    t.json "email_signatures", default: {}, null: false
    t.json "feature_flags", default: [], null: false
    t.json "features", default: [], null: false
    t.integer "fiscal_year_start_month", default: 1, null: false
    t.string "iban"
    t.string "icalendar_auth_token"
    t.json "invoice_document_names", default: {}, null: false
    t.json "invoice_footers", default: {}, null: false
    t.json "invoice_infos", default: {}, null: false
    t.json "invoice_sepa_infos", default: {}, null: false
    t.json "languages", default: ["fr"], null: false
    t.string "member_come_from_form_mode", default: "visible", null: false
    t.boolean "member_form_extra_text_only", default: false, null: false
    t.string "member_form_mode", default: "membership", null: false
    t.json "member_information_titles", default: {}, null: false
    t.string "member_profession_form_mode", default: "visible", null: false
    t.string "members_subdomain", null: false
    t.boolean "membership_complements_update_allowed", default: false, null: false
    t.boolean "membership_depot_update_allowed", default: false, null: false
    t.boolean "membership_renewal_depot_update", default: true, null: false
    t.json "membership_renewed_attributes", default: ["baskets_annual_price_change", "basket_complements_annual_price_change", "activity_participations_demanded_annually", "activity_participations_annual_price_change", "absences_included_annually"]
    t.string "name", null: false
    t.decimal "new_member_fee", precision: 8, scale: 2
    t.json "new_member_fee_descriptions", default: {}, null: false
    t.integer "open_renewal_reminder_sent_after_in_days"
    t.string "phone"
    t.json "privacy_policy_urls", default: {}, null: false
    t.integer "recurring_billing_wday"
    t.boolean "send_closed_invoice", default: false, null: false
    t.string "sepa_creditor_identifier"
    t.decimal "share_price", precision: 8, scale: 2
    t.integer "shares_number"
    t.boolean "shop_admin_only", default: true, null: false
    t.integer "shop_delivery_open_delay_in_days"
    t.string "shop_delivery_open_last_day_end_time"
    t.json "shop_delivery_pdf_footers", default: {}, null: false
    t.json "shop_invoice_infos", default: {}, null: false
    t.json "shop_member_percentages", default: [], null: false
    t.integer "shop_order_automatic_invoicing_delay_in_days"
    t.decimal "shop_order_maximum_weight_in_kg", precision: 8, scale: 3
    t.decimal "shop_order_minimal_amount", precision: 8, scale: 2
    t.json "shop_terms_of_sale_urls", default: {}, null: false
    t.json "social_network_urls", default: [], null: false
    t.json "statutes_urls", default: {}, null: false
    t.json "terms_of_service_urls", default: {}, null: false
    t.integer "trial_baskets_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.decimal "vat_activity_rate", precision: 8, scale: 2
    t.decimal "vat_membership_rate", precision: 8, scale: 2
    t.string "vat_number"
    t.decimal "vat_shop_rate", precision: 8, scale: 2
    t.check_constraint "JSON_TYPE(basket_price_extras) = 'array'", name: "organizations_basket_price_extras_is_array"
    t.check_constraint "JSON_TYPE(billing_year_divisions) = 'array'", name: "organizations_billing_year_divisions_is_array"
    t.check_constraint "JSON_TYPE(email_notifications) = 'array'", name: "organizations_email_notifications_is_array"
    t.check_constraint "JSON_TYPE(feature_flags) = 'array'", name: "organizations_feature_flags_is_array"
    t.check_constraint "JSON_TYPE(features) = 'array'", name: "organizations_features_is_array"
    t.check_constraint "JSON_TYPE(languages) = 'array'", name: "organizations_languages_is_array"
    t.check_constraint "JSON_TYPE(membership_renewed_attributes) = 'array'", name: "organizations_membership_renewed_attributes_is_array"
    t.check_constraint "JSON_TYPE(shop_member_percentages) = 'array'", name: "organizations_shop_member_percentages_is_array"
    t.check_constraint "JSON_TYPE(social_network_urls) = 'array'", name: "organizations_social_network_urls_is_array"
  end

  create_table "payments", force: :cascade do |t|
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "fingerprint"
    t.datetime "ignored_at"
    t.bigint "invoice_id"
    t.bigint "member_id", null: false
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "index_payments_on_fingerprint", unique: true
    t.index ["invoice_id"], name: "index_payments_on_invoice_id"
    t.index ["member_id"], name: "index_payments_on_member_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "names", default: {}, null: false
    t.json "rights", default: {}, null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "admin_id"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "last_remote_addr"
    t.datetime "last_used_at"
    t.string "last_user_agent"
    t.bigint "member_id"
    t.string "remote_addr", null: false
    t.datetime "revoked_at"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.text "user_agent", null: false
    t.index ["admin_id"], name: "index_sessions_on_admin_id"
    t.index ["member_id"], name: "index_sessions_on_member_id"
    t.index ["token"], name: "index_sessions_on_token", unique: true
  end

  create_table "shop_order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "item_price", precision: 8, scale: 2, null: false
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "product_id", "product_variant_id"], name: "shop_order_items_unique_index", unique: true
  end

  create_table "shop_orders", force: :cascade do |t|
    t.decimal "amount", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "amount_before_percentage", precision: 8, scale: 2
    t.decimal "amount_percentage", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.bigint "delivery_id", null: false
    t.string "delivery_type", default: "Delivery", null: false
    t.bigint "depot_id"
    t.bigint "member_id", null: false
    t.string "state", default: "cart", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_shop_orders_on_delivery_id"
    t.index ["depot_id"], name: "index_shop_orders_on_depot_id"
    t.index ["member_id", "delivery_type", "delivery_id"], name: "index_shop_orders_on_member_and_delivery", unique: true
    t.index ["state"], name: "index_shop_orders_on_state"
  end

  create_table "shop_producers", force: :cascade do |t|
    t.datetime "discarded_at"
    t.string "name", null: false
    t.string "website_url"
    t.index ["discarded_at"], name: "index_shop_producers_on_discarded_at"
  end

  create_table "shop_product_variants", force: :cascade do |t|
    t.boolean "available", default: true, null: false
    t.datetime "discarded_at"
    t.json "names", default: {}, null: false
    t.decimal "price", precision: 8, scale: 2, null: false
    t.bigint "product_id", null: false
    t.integer "stock"
    t.decimal "weight_in_kg", precision: 8, scale: 3
    t.index ["available"], name: "index_shop_product_variants_on_available"
    t.index ["discarded_at"], name: "index_shop_product_variants_on_discarded_at"
    t.index ["product_id"], name: "index_shop_product_variants_on_product_id"
  end

  create_table "shop_products", force: :cascade do |t|
    t.boolean "available", default: true, null: false
    t.bigint "basket_complement_id"
    t.datetime "discarded_at"
    t.boolean "display_in_delivery_sheets", default: false, null: false
    t.json "names", default: {}, null: false
    t.bigint "producer_id"
    t.json "unavailable_for_delivery_ids", default: [], null: false
    t.json "unavailable_for_depot_ids", default: [], null: false
    t.index ["available"], name: "index_shop_products_on_available"
    t.index ["basket_complement_id"], name: "index_shop_products_on_basket_complement_id", unique: true
    t.index ["discarded_at"], name: "index_shop_products_on_discarded_at"
    t.index ["producer_id"], name: "index_shop_products_on_producer_id"
    t.check_constraint "JSON_TYPE(unavailable_for_delivery_ids) = 'array'", name: "shop_products_unavailable_for_delivery_ids_is_array"
    t.check_constraint "JSON_TYPE(unavailable_for_depot_ids) = 'array'", name: "shop_products_unavailable_for_depot_ids_is_array"
  end

  create_table "shop_products_special_deliveries", id: false, force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "special_delivery_id", null: false
    t.index ["product_id"], name: "index_shop_products_special_deliveries_on_product_id"
    t.index ["special_delivery_id"], name: "index_shop_products_special_deliveries_on_special_delivery_id"
  end

  create_table "shop_products_tags", id: false, force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "tag_id", null: false
    t.index ["product_id", "tag_id"], name: "index_shop_products_tags_unique", unique: true
  end

  create_table "shop_special_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.boolean "open", default: false, null: false
    t.integer "open_delay_in_days"
    t.string "open_last_day_end_time"
    t.integer "shop_products_count", default: 0, null: false
    t.json "titles", default: {}
    t.json "unavailable_for_depot_ids", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_shop_special_deliveries_on_date", unique: true
    t.check_constraint "JSON_TYPE(unavailable_for_depot_ids) = 'array'", name: "shop_special_deliveries_unavailable_for_depot_ids_is_array"
  end

  create_table "shop_tags", force: :cascade do |t|
    t.datetime "discarded_at"
    t.string "emoji"
    t.json "names", default: {}, null: false
    t.index ["discarded_at"], name: "index_shop_tags_on_discarded_at"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activity_participations", "activities"
  add_foreign_key "activity_participations", "admins", column: "validator_id"
  add_foreign_key "activity_participations", "members"
  add_foreign_key "admins", "permissions"
  add_foreign_key "basket_contents", "basket_content_products", column: "product_id"
  add_foreign_key "basket_contents", "deliveries"
  add_foreign_key "basket_contents_depots", "basket_contents"
  add_foreign_key "basket_contents_depots", "depots"
  add_foreign_key "basket_shifts", "absences"
  add_foreign_key "basket_shifts", "baskets", column: "source_basket_id"
  add_foreign_key "basket_shifts", "baskets", column: "target_basket_id"
  add_foreign_key "basket_sizes", "delivery_cycles"
  add_foreign_key "baskets", "absences"
  add_foreign_key "baskets", "basket_sizes"
  add_foreign_key "baskets", "deliveries"
  add_foreign_key "baskets", "depots"
  add_foreign_key "baskets", "memberships"
  add_foreign_key "depots", "depot_groups", column: "group_id"
  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "members", "depots", column: "shop_depot_id"
  add_foreign_key "members", "depots", column: "waiting_depot_id"
  add_foreign_key "memberships", "delivery_cycles"
  add_foreign_key "memberships", "depots"
  add_foreign_key "memberships_basket_complements", "delivery_cycles"
  add_foreign_key "newsletter_blocks", "newsletters"
  add_foreign_key "newsletter_deliveries", "members"
  add_foreign_key "newsletter_deliveries", "newsletters"
  add_foreign_key "newsletters", "newsletter_templates"
  add_foreign_key "payments", "invoices"
  add_foreign_key "payments", "members"
  add_foreign_key "sessions", "admins"
  add_foreign_key "sessions", "members"
  add_foreign_key "shop_order_items", "shop_orders", column: "order_id"
  add_foreign_key "shop_order_items", "shop_product_variants", column: "product_variant_id"
  add_foreign_key "shop_order_items", "shop_products", column: "product_id"
  add_foreign_key "shop_orders", "depots"
  add_foreign_key "shop_orders", "members"
  add_foreign_key "shop_product_variants", "shop_products", column: "product_id"
  add_foreign_key "shop_products", "basket_complements"
  add_foreign_key "shop_products", "shop_producers", column: "producer_id"
  add_foreign_key "shop_products_special_deliveries", "shop_products", column: "product_id"
  add_foreign_key "shop_products_special_deliveries", "shop_special_deliveries", column: "special_delivery_id"
  add_foreign_key "shop_products_tags", "shop_products", column: "product_id"
  add_foreign_key "shop_products_tags", "shop_tags", column: "tag_id"
end
