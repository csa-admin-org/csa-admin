# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_06_07_185007) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "hstore"
  enable_extension "plpgsql"

  create_table "absences", id: :serial, force: :cascade do |t|
    t.integer "member_id"
    t.date "started_on"
    t.date "ended_on"
    t.text "note"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.bigint "session_id"
    t.index ["member_id"], name: "index_absences_on_member_id"
  end

  create_table "acps", force: :cascade do |t|
    t.string "name", null: false
    t.string "host", null: false
    t.string "tenant_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "features", default: [], null: false, array: true
    t.string "email_default_host"
    t.string "email_default_from"
    t.integer "fiscal_year_start_month", default: 1, null: false
    t.integer "trial_basket_count", default: 0, null: false
    t.decimal "annual_fee", precision: 8, scale: 2
    t.int4range "summer_month_range"
    t.string "ccp"
    t.string "isr_identity"
    t.text "isr_payment_for"
    t.text "isr_in_favor_of"
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
    t.string "logo_url"
    t.string "email_footer"
    t.string "activity_phone"
    t.decimal "activity_price", precision: 8, scale: 2, default: "0.0", null: false
    t.boolean "absences_billed", default: true, null: false
    t.jsonb "membership_extra_texts", default: {}, null: false
    t.index ["host"], name: "index_acps_on_host"
    t.index ["tenant_name"], name: "index_acps_on_tenant_name"
  end

  create_table "active_admin_comments", id: :serial, force: :cascade do |t|
    t.string "namespace", limit: 255
    t.text "body"
    t.string "resource_id", limit: 255, null: false
    t.string "resource_type", limit: 255, null: false
    t.integer "author_id"
    t.string "author_type", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "activities", id: :serial, force: :cascade do |t|
    t.date "date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.integer "participants_limit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.datetime "validated_at"
    t.datetime "rejected_at"
    t.integer "participants_count", default: 1, null: false
    t.string "carpooling_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "latest_reminder_sent_at"
    t.string "carpooling_city"
    t.bigint "session_id"
    t.datetime "review_sent_at"
    t.index ["activity_id"], name: "index_activity_participations_on_activity_id"
    t.index ["member_id"], name: "index_activity_participations_on_member_id"
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
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "rights", default: "standard", null: false
    t.string "name"
    t.string "notifications", default: [], null: false, array: true
    t.string "language", default: "fr", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "basket_complements", force: :cascade do |t|
    t.decimal "price", precision: 8, scale: 3, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "names", default: {}, null: false
    t.string "price_type", default: "delivery", null: false
  end

  create_table "basket_complements_deliveries", force: :cascade do |t|
    t.bigint "basket_complement_id", null: false
    t.bigint "delivery_id", null: false
    t.index ["basket_complement_id", "delivery_id"], name: "basket_complements_deliveries_unique_index", unique: true
  end

  create_table "basket_complements_members", force: :cascade do |t|
    t.bigint "basket_complement_id", null: false
    t.bigint "member_id", null: false
    t.index ["basket_complement_id", "member_id"], name: "basket_complements_members_unique_index", unique: true
  end

  create_table "basket_contents", id: :serial, force: :cascade do |t|
    t.integer "delivery_id", null: false
    t.integer "vegetable_id", null: false
    t.decimal "quantity", precision: 8, scale: 2, null: false
    t.string "unit", null: false
    t.decimal "small_basket_quantity", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "big_basket_quantity", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "lost_quantity", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "small_baskets_count", default: 0, null: false
    t.integer "big_baskets_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_basket_contents_on_delivery_id"
    t.index ["vegetable_id", "delivery_id"], name: "index_basket_contents_on_vegetable_id_and_delivery_id", unique: true
    t.index ["vegetable_id"], name: "index_basket_contents_on_vegetable_id"
  end

  create_table "basket_contents_depots", id: false, force: :cascade do |t|
    t.integer "basket_content_id", null: false
    t.integer "depot_id", null: false
    t.index ["basket_content_id", "depot_id"], name: "index_basket_contents_depots_unique", unique: true
    t.index ["basket_content_id"], name: "index_basket_contents_depots_on_basket_content_id"
    t.index ["depot_id"], name: "index_basket_contents_depots_on_depot_id"
  end

  create_table "basket_sizes", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal "price", precision: 8, scale: 3, default: "0.0", null: false
    t.integer "activity_participations_demanded_annualy", default: 0, null: false
    t.jsonb "names", default: {}, null: false
    t.integer "acp_shares_number"
  end

  create_table "baskets", force: :cascade do |t|
    t.bigint "membership_id", null: false
    t.bigint "delivery_id", null: false
    t.bigint "basket_size_id", null: false
    t.bigint "depot_id", null: false
    t.decimal "basket_price", precision: 8, scale: 3, null: false
    t.decimal "depot_price", precision: 8, scale: 2, null: false
    t.boolean "trial", default: false, null: false
    t.boolean "absent", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.integer "quantity", default: 1, null: false
    t.index ["basket_size_id"], name: "index_baskets_on_basket_size_id"
    t.index ["delivery_id"], name: "index_baskets_on_delivery_id"
    t.index ["depot_id"], name: "index_baskets_on_depot_id"
    t.index ["membership_id", "delivery_id"], name: "index_baskets_on_membership_id_and_delivery_id", unique: true
    t.index ["membership_id"], name: "index_baskets_on_membership_id"
  end

  create_table "baskets_basket_complements", force: :cascade do |t|
    t.bigint "basket_complement_id", null: false
    t.bigint "basket_id", null: false
    t.decimal "price", precision: 8, scale: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "quantity", default: 1, null: false
    t.index ["basket_complement_id", "basket_id"], name: "baskets_basket_complements_unique_index", unique: true
  end

  create_table "deliveries", id: :serial, force: :cascade do |t|
    t.date "date", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "note"
    t.integer "number", default: 0, null: false
    t.index ["date"], name: "index_deliveries_on_date"
  end

  create_table "deliveries_depots", force: :cascade do |t|
    t.bigint "depot_id", null: false
    t.bigint "delivery_id", null: false
    t.index ["depot_id", "delivery_id"], name: "deliveries_depots_unique_index", unique: true
  end

  create_table "depots", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "address", limit: 255
    t.string "zip", limit: 255
    t.string "city", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal "price", precision: 8, scale: 2, null: false
    t.string "emails"
    t.bigint "responsible_member_id"
    t.string "address_name"
    t.string "phones"
    t.text "note"
    t.string "language", default: "fr", null: false
    t.boolean "visible", default: true, null: false
    t.jsonb "form_names", default: {}, null: false
    t.integer "form_priority", default: 0, null: false
    t.index ["responsible_member_id"], name: "index_depots_on_responsible_member_id"
    t.index ["visible"], name: "index_depots_on_visible"
  end

  create_table "gribouilles", id: :serial, force: :cascade do |t|
    t.integer "delivery_id", null: false
    t.text "header"
    t.text "basket_content"
    t.text "fields_echo"
    t.text "events"
    t.text "footer"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_gribouilles_on_delivery_id"
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "invoice_id"
    t.string "description", null: false
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
  end

  create_table "invoices", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.date "date", null: false
    t.decimal "balance", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.decimal "annual_fee", precision: 8, scale: 2
    t.string "memberships_amount_description"
    t.decimal "memberships_amount", precision: 8, scale: 2
    t.decimal "remaining_memberships_amount", precision: 8, scale: 2
    t.decimal "paid_memberships_amount", precision: 8, scale: 2
    t.datetime "sent_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "overdue_notices_count", default: 0, null: false
    t.datetime "overdue_notice_sent_at"
    t.datetime "canceled_at"
    t.string "state", default: "not_sent", null: false
    t.string "object_type", null: false
    t.bigint "object_id"
    t.integer "paid_missing_activity_participations"
    t.decimal "memberships_vat_amount", precision: 8, scale: 2
    t.integer "acp_shares_number"
    t.index ["member_id"], name: "index_invoices_on_member_id"
    t.index ["object_type", "object_id"], name: "index_invoices_on_object_type_and_object_id"
    t.index ["state"], name: "index_invoices_on_state"
  end

  create_table "members", id: :serial, force: :cascade do |t|
    t.string "emails"
    t.string "phones", limit: 255
    t.string "address", limit: 255
    t.string "zip", limit: 255
    t.string "city", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "waiting_started_at"
    t.text "food_note"
    t.text "note"
    t.integer "validator_id"
    t.datetime "validated_at"
    t.boolean "newsletter"
    t.integer "waiting_basket_size_id"
    t.integer "waiting_depot_id"
    t.boolean "salary_basket", default: false
    t.string "delivery_address", limit: 255
    t.string "delivery_zip", limit: 255
    t.string "delivery_city", limit: 255
    t.datetime "deleted_at"
    t.datetime "welcome_email_sent_at"
    t.string "state", default: "pending", null: false
    t.string "name", null: false
    t.string "profession"
    t.string "come_from"
    t.decimal "annual_fee", precision: 8, scale: 2
    t.integer "billing_year_division", default: 1, null: false
    t.string "language", default: "fr", null: false
    t.string "acp_shares_info"
    t.integer "existing_acp_shares_number", default: 0, null: false
    t.index ["deleted_at"], name: "index_members_on_deleted_at"
    t.index ["state"], name: "index_members_on_state"
    t.index ["waiting_basket_size_id"], name: "index_members_on_waiting_basket_size_id"
    t.index ["waiting_depot_id"], name: "index_members_on_waiting_depot_id"
    t.index ["waiting_started_at"], name: "index_members_on_waiting_started_at"
    t.index ["welcome_email_sent_at"], name: "index_members_on_welcome_email_sent_at"
  end

  create_table "memberships", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.decimal "activity_participations_annual_price_change", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "activity_participations_demanded_annualy", null: false
    t.date "started_on", null: false
    t.date "ended_on", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.integer "baskets_count", default: 0, null: false
    t.integer "activity_participations_demanded", default: 0, null: false
    t.integer "activity_participations_accepted", default: 0, null: false
    t.boolean "renew", default: false, null: false
    t.bigint "basket_size_id", null: false
    t.bigint "depot_id", null: false
    t.integer "basket_quantity", default: 1, null: false
    t.decimal "basket_price", precision: 8, scale: 3, null: false
    t.decimal "depot_price", precision: 8, scale: 3, null: false
    t.string "seasons", default: ["summer", "winter"], null: false, array: true
    t.decimal "baskets_annual_price_change", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "basket_complements_annual_price_change", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "delivered_baskets_count", default: 0, null: false
    t.integer "remaning_trial_baskets_count", default: 0, null: false
    t.decimal "price", precision: 8, scale: 2
    t.decimal "invoices_amount", precision: 8, scale: 2
    t.index ["basket_size_id"], name: "index_memberships_on_basket_size_id"
    t.index ["deleted_at"], name: "index_memberships_on_deleted_at"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "seasons", default: ["summer", "winter"], null: false, array: true
    t.index ["basket_complement_id", "membership_id"], name: "memberships_basket_complements_unique_index", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "member_id", null: false
    t.bigint "invoice_id"
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.date "date", null: false
    t.string "isr_data"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_payments_on_deleted_at"
    t.index ["invoice_id"], name: "index_payments_on_invoice_id"
    t.index ["isr_data"], name: "index_payments_on_isr_data", unique: true
    t.index ["member_id"], name: "index_payments_on_member_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "member_id"
    t.string "token", null: false
    t.text "user_agent", null: false
    t.string "remote_addr", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_used_at"
    t.string "last_remote_addr"
    t.string "last_user_agent"
    t.string "email"
    t.bigint "admin_id"
    t.index ["admin_id"], name: "index_sessions_on_admin_id"
    t.index ["member_id"], name: "index_sessions_on_member_id"
    t.index ["token"], name: "index_sessions_on_token", unique: true
  end

  create_table "vegetables", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "names", default: {}, null: false
  end

  add_foreign_key "activity_participations", "activities"
  add_foreign_key "activity_participations", "admins", column: "validator_id"
  add_foreign_key "activity_participations", "members"
  add_foreign_key "basket_contents", "deliveries"
  add_foreign_key "basket_contents", "vegetables"
  add_foreign_key "basket_contents_depots", "basket_contents"
  add_foreign_key "basket_contents_depots", "depots"
  add_foreign_key "baskets", "basket_sizes"
  add_foreign_key "baskets", "deliveries"
  add_foreign_key "baskets", "depots"
  add_foreign_key "baskets", "memberships"
  add_foreign_key "depots", "members", column: "responsible_member_id"
  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "members", "depots", column: "waiting_depot_id"
  add_foreign_key "memberships", "depots"
  add_foreign_key "payments", "invoices"
  add_foreign_key "payments", "members"
  add_foreign_key "sessions", "admins"
  add_foreign_key "sessions", "members"
end
