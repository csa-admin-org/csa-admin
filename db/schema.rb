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

ActiveRecord::Schema[8.0].define(version: 2024_10_19_102158) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "hstore"
  enable_extension "pg_catalog.plpgsql"

  create_table "absences", id: :serial, force: :cascade do |t|
    t.integer "member_id"
    t.date "started_on"
    t.date "ended_on"
    t.text "note"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.bigint "session_id"
    t.index ["member_id"], name: "index_absences_on_member_id"
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_admin_comments", id: :serial, force: :cascade do |t|
    t.string "namespace", limit: 255
    t.text "body"
    t.string "resource_id", limit: 255, null: false
    t.string "resource_type", limit: 255, null: false
    t.integer "author_id"
    t.string "author_type", limit: 255
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", precision: nil, null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", id: :serial, force: :cascade do |t|
    t.date "date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.integer "participants_limit"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.jsonb "places", default: {}, null: false
    t.jsonb "place_urls", default: {}, null: false
    t.jsonb "titles", default: {}, null: false
    t.jsonb "descriptions", default: {}, null: false
    t.index ["date"], name: "index_activities_on_date"
    t.index ["start_time"], name: "index_activities_on_start_time"
  end

  create_table "activity_participations", id: :serial, force: :cascade do |t|
    t.integer "activity_id", null: false
    t.integer "member_id", null: false
    t.integer "validator_id"
    t.string "state", default: "pending", null: false
    t.datetime "validated_at", precision: nil
    t.datetime "rejected_at", precision: nil
    t.integer "participants_count", default: 1, null: false
    t.string "carpooling_phone"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "latest_reminder_sent_at", precision: nil
    t.string "carpooling_city"
    t.bigint "session_id"
    t.datetime "review_sent_at", precision: nil
    t.text "note"
    t.datetime "admins_notified_at"
    t.index ["activity_id"], name: "index_activity_participations_on_activity_id"
    t.index ["member_id"], name: "index_activity_participations_on_member_id"
    t.index ["state"], name: "index_activity_participations_on_state"
    t.index ["validator_id"], name: "index_activity_participations_on_validator_id"
  end

  create_table "activity_presets", force: :cascade do |t|
    t.jsonb "places", default: {}, null: false
    t.jsonb "place_urls", default: {}, null: false
    t.jsonb "titles", default: {}, null: false
    t.index ["places", "titles"], name: "index_activity_presets_on_places_and_titles", unique: true
  end

  create_table "admins", id: :serial, force: :cascade do |t|
    t.string "email", limit: 255, default: "", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "name", null: false
    t.string "notifications", default: [], null: false, array: true
    t.string "language", default: "fr", null: false
    t.string "latest_update_read"
    t.bigint "permission_id", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["permission_id"], name: "index_admins_on_permission_id"
  end

  create_table "announcements", force: :cascade do |t|
    t.jsonb "texts", default: {}, null: false
    t.integer "delivery_ids", default: [], null: false, array: true
    t.integer "depot_ids", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "audits", force: :cascade do |t|
    t.bigint "session_id"
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.jsonb "audited_changes", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audits_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["session_id"], name: "index_audits_on_session_id"
  end

  create_table "basket_complements", force: :cascade do |t|
    t.decimal "price", precision: 8, scale: 3, default: "0.0", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.jsonb "names", default: {}, null: false
    t.boolean "visible", default: true, null: false
    t.jsonb "public_names", default: {}, null: false
    t.jsonb "form_details", default: {}, null: false
    t.integer "member_order_priority", default: 1, null: false
    t.integer "activity_participations_demanded_annually", default: 0, null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_basket_complements_on_discarded_at"
    t.index ["visible"], name: "index_basket_complements_on_visible"
  end

  create_table "basket_complements_deliveries", force: :cascade do |t|
    t.bigint "basket_complement_id", null: false
    t.bigint "delivery_id", null: false
    t.index ["basket_complement_id", "delivery_id"], name: "basket_complements_deliveries_unique_index", unique: true
  end

  create_table "basket_content_products", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.jsonb "names", default: {}, null: false
    t.string "url"
  end

  create_table "basket_contents", id: :serial, force: :cascade do |t|
    t.integer "delivery_id", null: false
    t.integer "product_id", null: false
    t.decimal "quantity", precision: 8, scale: 2, null: false
    t.string "unit", null: false
    t.decimal "surplus_quantity", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.decimal "basket_quantities", precision: 8, scale: 3, default: [], null: false, array: true
    t.integer "baskets_counts", default: [], null: false, array: true
    t.integer "basket_size_ids", default: [], null: false, array: true
    t.integer "basket_percentages", default: [], null: false, array: true
    t.decimal "unit_price", precision: 8, scale: 2
    t.string "distribution_mode", default: "automatic", null: false
    t.index ["delivery_id"], name: "index_basket_contents_on_delivery_id"
    t.index ["product_id"], name: "index_basket_contents_on_product_id"
  end

  create_table "basket_contents_depots", id: false, force: :cascade do |t|
    t.integer "basket_content_id", null: false
    t.integer "depot_id", null: false
    t.index ["basket_content_id", "depot_id"], name: "index_basket_contents_depots_unique", unique: true
    t.index ["basket_content_id"], name: "index_basket_contents_depots_on_basket_content_id"
    t.index ["depot_id"], name: "index_basket_contents_depots_on_depot_id"
  end

  create_table "basket_sizes", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.decimal "price", precision: 8, scale: 3, default: "0.0", null: false
    t.integer "activity_participations_demanded_annually", default: 0, null: false
    t.jsonb "names", default: {}, null: false
    t.integer "shares_number"
    t.boolean "visible", default: true, null: false
    t.jsonb "public_names", default: {}, null: false
    t.jsonb "form_details", default: {}, null: false
    t.integer "member_order_priority", default: 1, null: false
    t.bigint "delivery_cycle_id"
    t.datetime "discarded_at"
    t.index ["delivery_cycle_id"], name: "index_basket_sizes_on_delivery_cycle_id"
    t.index ["discarded_at"], name: "index_basket_sizes_on_discarded_at"
    t.index ["visible"], name: "index_basket_sizes_on_visible"
  end

  create_table "baskets", force: :cascade do |t|
    t.bigint "membership_id", null: false
    t.bigint "delivery_id", null: false
    t.bigint "basket_size_id", null: false
    t.bigint "depot_id", null: false
    t.decimal "basket_price", precision: 8, scale: 3, null: false
    t.decimal "depot_price", precision: 8, scale: 2, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "calculated_price_extra", precision: 8, scale: 3, default: "0.0", null: false
    t.decimal "price_extra", precision: 8, scale: 2, default: "0.0", null: false
    t.string "state", default: "normal", null: false
    t.bigint "absence_id"
    t.boolean "billable", default: true, null: false
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
    t.decimal "price", precision: 8, scale: 3, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "quantity", default: 1, null: false
    t.index ["basket_complement_id", "basket_id"], name: "baskets_basket_complements_unique_index", unique: true
  end

  create_table "billing_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "deliveries", id: :serial, force: :cascade do |t|
    t.date "date", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.text "note"
    t.integer "number", default: 0, null: false
    t.boolean "shop_open", default: true
    t.jsonb "basket_content_avg_prices", default: {}
    t.integer "shop_closed_for_depot_ids", default: [], array: true
    t.index ["date"], name: "index_deliveries_on_date", unique: true
    t.index ["shop_open"], name: "index_deliveries_on_shop_open"
  end

  create_table "delivery_cycles", force: :cascade do |t|
    t.jsonb "names", default: {}, null: false
    t.jsonb "public_names", default: {}, null: false
    t.integer "wdays", default: [0, 1, 2, 3, 4, 5, 6], null: false, array: true
    t.integer "months", default: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], null: false, array: true
    t.integer "week_numbers", default: 0, null: false
    t.integer "results", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "deliveries_counts", default: {}, null: false
    t.integer "member_order_priority", default: 1, null: false
    t.integer "minimum_gap_in_days"
    t.integer "absences_included_annually", default: 0, null: false
    t.datetime "discarded_at"
    t.jsonb "form_details", default: {}, null: false
    t.index ["discarded_at"], name: "index_delivery_cycles_on_discarded_at"
  end

  create_table "delivery_cycles_depots", force: :cascade do |t|
    t.bigint "depot_id", null: false
    t.bigint "delivery_cycle_id", null: false
    t.index ["depot_id", "delivery_cycle_id"], name: "index_delivery_cycles_depots_on_depot_id_and_delivery_cycle_id", unique: true
  end

  create_table "depot_groups", force: :cascade do |t|
    t.jsonb "names", default: {}, null: false
    t.jsonb "public_names", default: {}, null: false
    t.integer "member_order_priority", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "depots", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "address", limit: 255
    t.string "zip", limit: 255
    t.string "city", limit: 255
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.decimal "price", precision: 8, scale: 2, null: false
    t.string "emails"
    t.string "address_name"
    t.string "phones"
    t.text "note"
    t.string "language", default: "fr", null: false
    t.boolean "visible", default: true, null: false
    t.jsonb "public_names", default: {}, null: false
    t.string "contact_name"
    t.integer "member_order_priority", default: 1, null: false
    t.integer "position"
    t.integer "member_ids_position", default: [], array: true
    t.string "delivery_sheets_mode", default: "signature", null: false
    t.bigint "group_id"
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_depots_on_discarded_at"
    t.index ["group_id"], name: "index_depots_on_group_id"
    t.index ["visible"], name: "index_depots_on_visible"
  end

  create_table "email_suppressions", force: :cascade do |t|
    t.string "email"
    t.string "reason"
    t.string "origin"
    t.string "stream_id"
    t.datetime "unsuppressed_at", precision: nil
    t.datetime "created_at", precision: nil
    t.index ["stream_id", "email", "reason", "origin", "created_at"], name: "email_suppressions_unique_index", unique: true
  end

  create_table "gribouilles", id: :serial, force: :cascade do |t|
    t.integer "delivery_id", null: false
    t.text "header"
    t.text "basket_content"
    t.text "fields_echo"
    t.text "events"
    t.text "footer"
    t.datetime "sent_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["delivery_id"], name: "index_gribouilles_on_delivery_id"
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "invoice_id"
    t.string "description", null: false
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
  end

  create_table "invoices", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.date "date", null: false
    t.decimal "paid_amount", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.decimal "annual_fee", precision: 8, scale: 2
    t.string "memberships_amount_description"
    t.decimal "memberships_amount", precision: 8, scale: 2
    t.decimal "remaining_memberships_amount", precision: 8, scale: 2
    t.decimal "paid_memberships_amount", precision: 8, scale: 2
    t.datetime "sent_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "overdue_notices_count", default: 0, null: false
    t.datetime "overdue_notice_sent_at", precision: nil
    t.datetime "canceled_at", precision: nil
    t.string "state", default: "processing", null: false
    t.string "entity_type", null: false
    t.bigint "entity_id"
    t.integer "missing_activity_participations_count"
    t.decimal "vat_amount", precision: 8, scale: 2
    t.integer "shares_number"
    t.datetime "overpaid_notification_sent_at", precision: nil
    t.decimal "vat_rate", precision: 8, scale: 2
    t.decimal "amount_percentage", precision: 8, scale: 2
    t.decimal "amount_before_percentage", precision: 8, scale: 2
    t.datetime "stamped_at"
    t.integer "missing_activity_participations_fiscal_year"
    t.index ["entity_type", "entity_id"], name: "index_invoices_on_entity_type_and_entity_id"
    t.index ["member_id"], name: "index_invoices_on_member_id"
    t.index ["state"], name: "index_invoices_on_state"
  end

  create_table "mail_templates", force: :cascade do |t|
    t.string "title", null: false
    t.boolean "active", default: false, null: false
    t.jsonb "subjects", default: {}, null: false
    t.jsonb "contents", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_mail_templates_on_title", unique: true
  end

  create_table "members", id: :serial, force: :cascade do |t|
    t.string "emails"
    t.string "phones", limit: 255
    t.string "address", limit: 255
    t.string "zip", limit: 255
    t.string "city", limit: 255
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.datetime "waiting_started_at", precision: nil
    t.text "food_note"
    t.text "note"
    t.integer "validator_id"
    t.datetime "validated_at", precision: nil
    t.boolean "newsletter"
    t.integer "waiting_basket_size_id"
    t.integer "waiting_depot_id"
    t.boolean "salary_basket", default: false
    t.string "delivery_address", limit: 255
    t.string "delivery_zip", limit: 255
    t.string "delivery_city", limit: 255
    t.string "state", default: "pending", null: false
    t.string "name", null: false
    t.string "profession"
    t.text "come_from"
    t.decimal "annual_fee", precision: 8, scale: 2
    t.string "language", default: "fr", null: false
    t.string "shares_info"
    t.integer "existing_shares_number", default: 0, null: false
    t.datetime "activated_at", precision: nil
    t.decimal "waiting_basket_price_extra", precision: 8, scale: 2
    t.string "country_code", limit: 2
    t.boolean "contact_sharing", default: false, null: false
    t.integer "desired_shares_number", default: 0, null: false
    t.bigint "waiting_delivery_cycle_id"
    t.string "billing_email"
    t.integer "memberships_count", default: 0, null: false
    t.bigint "shop_depot_id"
    t.string "delivery_note"
    t.integer "required_shares_number"
    t.integer "waiting_activity_participations_demanded_annually"
    t.string "iban"
    t.string "sepa_mandate_id"
    t.date "sepa_mandate_signed_on"
    t.integer "waiting_billing_year_division"
    t.index ["shop_depot_id"], name: "index_members_on_shop_depot_id"
    t.index ["state"], name: "index_members_on_state"
    t.index ["waiting_basket_size_id"], name: "index_members_on_waiting_basket_size_id"
    t.index ["waiting_depot_id"], name: "index_members_on_waiting_depot_id"
    t.index ["waiting_started_at"], name: "index_members_on_waiting_started_at"
  end

  create_table "members_basket_complements", force: :cascade do |t|
    t.bigint "basket_complement_id", null: false
    t.bigint "member_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["basket_complement_id", "member_id"], name: "members_basket_complements_unique_index", unique: true
  end

  create_table "members_waiting_alternative_depots", id: false, force: :cascade do |t|
    t.bigint "depot_id", null: false
    t.bigint "member_id", null: false
  end

  create_table "memberships", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.decimal "activity_participations_annual_price_change", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "activity_participations_demanded_annually", null: false
    t.date "started_on", null: false
    t.date "ended_on", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "baskets_count", default: 0, null: false
    t.integer "activity_participations_demanded", default: 0, null: false
    t.integer "activity_participations_accepted", default: 0, null: false
    t.boolean "renew", default: false, null: false
    t.bigint "basket_size_id", null: false
    t.bigint "depot_id", null: false
    t.integer "basket_quantity", default: 1, null: false
    t.decimal "basket_price", precision: 8, scale: 3, null: false
    t.decimal "depot_price", precision: 8, scale: 3, null: false
    t.decimal "baskets_annual_price_change", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "basket_complements_annual_price_change", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "past_baskets_count", default: 0, null: false
    t.integer "remaning_trial_baskets_count", default: 0, null: false
    t.decimal "price", precision: 8, scale: 2
    t.decimal "invoices_amount", precision: 8, scale: 2
    t.decimal "renewal_annual_fee", precision: 8, scale: 2
    t.datetime "renewed_at", precision: nil
    t.datetime "renewal_opened_at", precision: nil
    t.text "renewal_note"
    t.datetime "renewal_reminder_sent_at", precision: nil
    t.decimal "basket_price_extra", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "last_trial_basket_sent_at", precision: nil
    t.bigint "delivery_cycle_id", null: false
    t.integer "absences_included_annually", null: false
    t.integer "absences_included", default: 0, null: false
    t.integer "billing_year_division", default: 1, null: false
    t.integer "trial_baskets_count", default: 0
    t.index ["basket_size_id"], name: "index_memberships_on_basket_size_id"
    t.index ["delivery_cycle_id"], name: "index_memberships_on_delivery_cycle_id"
    t.index ["depot_id"], name: "index_memberships_on_depot_id"
    t.index ["ended_on"], name: "index_memberships_on_ended_on"
    t.index ["member_id"], name: "index_memberships_on_member_id"
    t.index ["started_on"], name: "index_memberships_on_started_on"
  end

  create_table "memberships_basket_complements", force: :cascade do |t|
    t.bigint "basket_complement_id", null: false
    t.bigint "membership_id", null: false
    t.decimal "price", precision: 8, scale: 3, null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "delivery_cycle_id"
    t.index ["basket_complement_id", "membership_id"], name: "memberships_basket_complements_unique_index", unique: true
  end

  create_table "newsletter_attachments", force: :cascade do |t|
    t.bigint "newsletter_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["newsletter_id"], name: "index_newsletter_attachments_on_newsletter_id"
  end

  create_table "newsletter_blocks", force: :cascade do |t|
    t.bigint "newsletter_id", null: false
    t.string "block_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["newsletter_id", "block_id"], name: "index_newsletter_blocks_on_newsletter_id_and_block_id", unique: true
    t.index ["newsletter_id"], name: "index_newsletter_blocks_on_newsletter_id"
  end

  create_table "newsletter_deliveries", force: :cascade do |t|
    t.bigint "newsletter_id", null: false
    t.bigint "member_id", null: false
    t.string "subject"
    t.text "content"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.integer "email_suppression_ids", default: [], array: true
    t.string "email_suppression_reasons", default: [], array: true
    t.string "state", default: "processing", null: false
    t.datetime "delivered_at"
    t.string "postmark_message_id"
    t.text "postmark_details"
    t.datetime "bounced_at"
    t.string "bounce_type"
    t.integer "bounce_type_code"
    t.string "bounce_description"
    t.index ["member_id"], name: "index_newsletter_deliveries_on_member_id"
    t.index ["newsletter_id"], name: "index_newsletter_deliveries_on_newsletter_id"
    t.index ["state"], name: "index_newsletter_deliveries_on_state"
  end

  create_table "newsletter_segments", force: :cascade do |t|
    t.jsonb "titles", default: {}, null: false
    t.integer "depot_ids", default: [], null: false, array: true
    t.integer "basket_size_ids", default: [], null: false, array: true
    t.integer "basket_complement_ids", default: [], null: false, array: true
    t.integer "delivery_cycle_ids", default: [], null: false, array: true
    t.string "renewal_state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "first_membership"
    t.integer "coming_deliveries_in_days"
    t.integer "billing_year_division"
  end

  create_table "newsletter_templates", force: :cascade do |t|
    t.string "title", null: false
    t.jsonb "contents", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_newsletter_templates_on_title", unique: true
  end

  create_table "newsletters", force: :cascade do |t|
    t.bigint "newsletter_template_id", null: false
    t.jsonb "template_contents", default: {}, null: false
    t.jsonb "subjects", default: {}, null: false
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "audience", null: false
    t.jsonb "liquid_data_preview_yamls", default: {}, null: false
    t.string "from"
    t.jsonb "signatures", default: {}, null: false
    t.jsonb "audience_names", default: {}, null: false
    t.index ["newsletter_template_id"], name: "index_newsletters_on_newsletter_template_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "features", default: [], null: false, array: true
    t.string "email_default_from", null: false
    t.integer "fiscal_year_start_month", default: 1, null: false
    t.integer "trial_baskets_count", default: 0, null: false
    t.decimal "annual_fee", precision: 8, scale: 2
    t.integer "billing_year_divisions", default: [], null: false, array: true
    t.string "activity_i18n_scope", default: "halfday_work", null: false
    t.string "email"
    t.string "phone"
    t.string "url"
    t.integer "activity_participation_deletion_deadline_in_days"
    t.string "vat_number"
    t.decimal "vat_membership_rate", precision: 8, scale: 2
    t.string "languages", default: ["fr"], null: false, array: true
    t.decimal "share_price", precision: 8, scale: 2
    t.jsonb "invoice_infos", default: {}, null: false
    t.jsonb "invoice_footers", default: {}, null: false
    t.jsonb "delivery_pdf_footers", default: {}, null: false
    t.jsonb "terms_of_service_urls", default: {}, null: false
    t.jsonb "statutes_urls", default: {}, null: false
    t.integer "activity_availability_limit_in_days", default: 3, null: false
    t.string "activity_phone"
    t.decimal "activity_price", precision: 8, scale: 2, default: "0.0", null: false
    t.boolean "absences_billed", default: true, null: false
    t.integer "recurring_billing_wday"
    t.string "email_notifications", default: [], null: false, array: true
    t.string "feature_flags", default: [], null: false, array: true
    t.integer "open_renewal_reminder_sent_after_in_days"
    t.string "iban"
    t.string "creditor_name", limit: 70
    t.string "creditor_address", limit: 70
    t.string "creditor_city", limit: 35
    t.string "creditor_zip", limit: 16
    t.string "country_code", limit: 2, default: "CH", null: false
    t.string "currency_code", limit: 3, default: "CHF"
    t.jsonb "email_signatures", default: {}, null: false
    t.jsonb "email_footers", default: {}, null: false
    t.boolean "billing_starts_after_first_delivery", default: true, null: false
    t.boolean "allow_alternative_depots", default: false, null: false
    t.boolean "member_form_extra_text_only", default: false, null: false
    t.decimal "basket_price_extras", precision: 8, scale: 2, default: [], null: false, array: true
    t.jsonb "basket_price_extra_titles", default: {}, null: false
    t.jsonb "basket_price_extra_texts", default: {}, null: false
    t.jsonb "basket_price_extra_labels", default: {}, null: false
    t.jsonb "basket_price_extra_label_details", default: {}, null: false
    t.boolean "membership_renewal_depot_update", default: true, null: false
    t.integer "absence_notice_period_in_days", default: 7, null: false
    t.jsonb "shop_invoice_infos", default: {}, null: false
    t.decimal "shop_order_maximum_weight_in_kg", precision: 8, scale: 3
    t.decimal "shop_order_minimal_amount", precision: 8, scale: 2
    t.integer "shop_delivery_open_delay_in_days"
    t.time "shop_delivery_open_last_day_end_time"
    t.jsonb "shop_delivery_pdf_footers", default: {}, null: false
    t.jsonb "shop_terms_of_sale_urls", default: {}, null: false
    t.boolean "absence_extra_text_only", default: false, null: false
    t.boolean "shop_admin_only", default: true, null: false
    t.jsonb "basket_price_extra_public_titles", default: {}, null: false
    t.string "icalendar_auth_token"
    t.string "bank_reference"
    t.text "activity_participations_demanded_logic", default: "{% if member.salary_basket %}\n  0\n{% else %}\n  {{ membership.baskets | divided_by: membership.full_year_deliveries | times: membership.full_year_activity_participations | round }}\n{% endif %}\n", null: false
    t.boolean "send_closed_invoice", default: false, null: false
    t.string "member_profession_form_mode", default: "visible", null: false
    t.string "member_come_from_form_mode", default: "visible", null: false
    t.integer "basket_update_limit_in_days", default: 0, null: false
    t.boolean "membership_depot_update_allowed", default: false, null: false
    t.text "basket_price_extra_dynamic_pricing"
    t.decimal "vat_activity_rate", precision: 8, scale: 2
    t.decimal "vat_shop_rate", precision: 8, scale: 2
    t.string "member_form_mode", default: "membership", null: false
    t.boolean "membership_complements_update_allowed", default: false, null: false
    t.decimal "shop_member_percentages", precision: 8, scale: 2, default: [], null: false, array: true
    t.string "basket_sizes_member_order_mode", default: "price_desc", null: false
    t.string "basket_complements_member_order_mode", default: "deliveries_count_desc", null: false
    t.string "depots_member_order_mode", default: "price_asc", null: false
    t.string "delivery_cycles_member_order_mode", default: "deliveries_count_desc", null: false
    t.integer "shop_order_automatic_invoicing_delay_in_days"
    t.string "membership_renewed_attributes", default: ["baskets_annual_price_change", "basket_complements_annual_price_change", "activity_participations_demanded_annually", "activity_participations_annual_price_change", "absences_included_annually"], array: true
    t.decimal "new_member_fee", precision: 8, scale: 2
    t.jsonb "new_member_fee_descriptions", default: {}, null: false
    t.jsonb "member_information_titles", default: {}, null: false
    t.boolean "billing_ends_on_last_delivery_fy_month", default: false, null: false
    t.integer "shares_number"
    t.jsonb "privacy_policy_urls", default: {}, null: false
    t.jsonb "charter_urls", default: {}, null: false
    t.integer "activity_participations_form_min"
    t.integer "activity_participations_form_max"
    t.jsonb "activity_participations_form_details", default: {}, null: false
    t.string "sepa_creditor_identifier"
    t.string "delivery_pdf_member_info", default: "none", null: false
    t.string "members_subdomain", null: false
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "member_id", null: false
    t.bigint "invoice_id"
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.date "date", null: false
    t.string "fingerprint"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["fingerprint"], name: "index_payments_on_fingerprint", unique: true
    t.index ["invoice_id"], name: "index_payments_on_invoice_id"
    t.index ["member_id"], name: "index_payments_on_member_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.jsonb "names", default: {}, null: false
    t.jsonb "rights", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "member_id"
    t.string "token", null: false
    t.text "user_agent", null: false
    t.string "remote_addr", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "last_used_at", precision: nil
    t.string "last_remote_addr"
    t.string "last_user_agent"
    t.string "email"
    t.bigint "admin_id"
    t.datetime "revoked_at"
    t.index ["admin_id"], name: "index_sessions_on_admin_id"
    t.index ["member_id"], name: "index_sessions_on_member_id"
    t.index ["token"], name: "index_sessions_on_token", unique: true
  end

  create_table "shop_order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "item_price", precision: 8, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "product_id", "product_variant_id"], name: "shop_order_items_unique_index", unique: true
  end

  create_table "shop_orders", force: :cascade do |t|
    t.bigint "member_id", null: false
    t.bigint "delivery_id", null: false
    t.string "state", default: "cart", null: false
    t.decimal "amount", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "delivery_type", default: "Delivery", null: false
    t.bigint "depot_id"
    t.decimal "amount_percentage", precision: 8, scale: 2
    t.decimal "amount_before_percentage", precision: 8, scale: 2
    t.index ["delivery_id"], name: "index_shop_orders_on_delivery_id"
    t.index ["depot_id"], name: "index_shop_orders_on_depot_id"
    t.index ["member_id", "delivery_type", "delivery_id"], name: "index_shop_orders_on_member_and_delivery", unique: true
    t.index ["state"], name: "index_shop_orders_on_state"
  end

  create_table "shop_producers", force: :cascade do |t|
    t.string "name", null: false
    t.string "website_url"
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_shop_producers_on_discarded_at"
  end

  create_table "shop_product_variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.jsonb "names", default: {}, null: false
    t.decimal "price", precision: 8, scale: 2, null: false
    t.decimal "weight_in_kg", precision: 8, scale: 3
    t.integer "stock"
    t.boolean "available", default: true, null: false
    t.datetime "discarded_at"
    t.index ["available"], name: "index_shop_product_variants_on_available"
    t.index ["discarded_at"], name: "index_shop_product_variants_on_discarded_at"
    t.index ["product_id"], name: "index_shop_product_variants_on_product_id"
  end

  create_table "shop_products", force: :cascade do |t|
    t.bigint "producer_id"
    t.jsonb "names", default: {}, null: false
    t.boolean "available", default: true, null: false
    t.bigint "basket_complement_id"
    t.integer "unavailable_for_depot_ids", default: [], array: true
    t.integer "unavailable_for_delivery_ids", default: [], null: false, array: true
    t.boolean "display_in_delivery_sheets", default: false, null: false
    t.datetime "discarded_at"
    t.index ["available"], name: "index_shop_products_on_available"
    t.index ["basket_complement_id"], name: "index_shop_products_on_basket_complement_id", unique: true
    t.index ["discarded_at"], name: "index_shop_products_on_discarded_at"
    t.index ["producer_id"], name: "index_shop_products_on_producer_id"
  end

  create_table "shop_products_special_deliveries", id: false, force: :cascade do |t|
    t.bigint "special_delivery_id", null: false
    t.bigint "product_id", null: false
    t.index ["special_delivery_id"], name: "index_shop_products_special_deliveries_on_special_delivery_id"
  end

  create_table "shop_products_tags", id: false, force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "tag_id", null: false
    t.index ["product_id", "tag_id"], name: "index_shop_products_tags_unique", unique: true
  end

  create_table "shop_special_deliveries", force: :cascade do |t|
    t.date "date", null: false
    t.integer "open_delay_in_days"
    t.time "open_last_day_end_time"
    t.boolean "open", default: false, null: false
    t.integer "shop_products_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "titles", default: {}
    t.index ["date"], name: "index_shop_special_deliveries_on_date", unique: true
  end

  create_table "shop_tags", force: :cascade do |t|
    t.jsonb "names", default: {}, null: false
    t.string "emoji"
    t.datetime "discarded_at"
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
  add_foreign_key "newsletter_attachments", "newsletters"
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
