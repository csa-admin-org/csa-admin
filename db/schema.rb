# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20151220192823) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "hstore"

  create_table "absences", force: :cascade do |t|
    t.integer  "member_id"
    t.date     "started_on"
    t.date     "ended_on"
    t.text     "note"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "absences", ["member_id"], name: "index_absences_on_member_id", using: :btree

  create_table "active_admin_comments", force: :cascade do |t|
    t.string   "namespace",     limit: 255
    t.text     "body"
    t.string   "resource_id",   limit: 255, null: false
    t.string   "resource_type", limit: 255, null: false
    t.integer  "author_id"
    t.string   "author_type",   limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "active_admin_comments", ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id", using: :btree
  add_index "active_admin_comments", ["namespace"], name: "index_active_admin_comments_on_namespace", using: :btree
  add_index "active_admin_comments", ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id", using: :btree

  create_table "admins", force: :cascade do |t|
    t.string   "email",                  limit: 255, default: "", null: false
    t.string   "encrypted_password",     limit: 255, default: "", null: false
    t.string   "reset_password_token",   limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                      default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 255
    t.string   "last_sign_in_ip",        limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "admins", ["email"], name: "index_admins_on_email", unique: true, using: :btree
  add_index "admins", ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true, using: :btree

  create_table "baskets", force: :cascade do |t|
    t.string   "name",         limit: 255,                         null: false
    t.integer  "year",                                             null: false
    t.decimal  "annual_price",             precision: 8, scale: 2, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "deliveries", force: :cascade do |t|
    t.date     "date",       null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "deliveries", ["date"], name: "index_deliveries_on_date", using: :btree

  create_table "distributions", force: :cascade do |t|
    t.string   "name",         limit: 255
    t.string   "address",      limit: 255
    t.string   "zip",          limit: 255
    t.string   "city",         limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal  "basket_price",             precision: 8, scale: 2, null: false
  end

  create_table "halfday_work_dates", force: :cascade do |t|
    t.date     "date",               null: false
    t.string   "periods",            null: false, array: true
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.integer  "participants_limit"
  end

  add_index "halfday_work_dates", ["date"], name: "index_halfday_work_dates_on_date", using: :btree

  create_table "halfday_works", force: :cascade do |t|
    t.integer  "member_id",                                  null: false
    t.date     "date",                                       null: false
    t.string   "periods",            limit: 255,             null: false, array: true
    t.datetime "validated_at"
    t.integer  "validator_id"
    t.integer  "participants_count",             default: 1, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "rejected_at"
  end

  add_index "halfday_works", ["date"], name: "index_halfday_works_on_date", using: :btree
  add_index "halfday_works", ["member_id"], name: "index_halfday_works_on_member_id", using: :btree
  add_index "halfday_works", ["rejected_at"], name: "index_halfday_works_on_rejected_at", using: :btree
  add_index "halfday_works", ["validated_at"], name: "index_halfday_works_on_validated_at", using: :btree
  add_index "halfday_works", ["validator_id"], name: "index_halfday_works_on_validator_id", using: :btree

  create_table "invoices", force: :cascade do |t|
    t.integer  "member_id",                                                            null: false
    t.date     "date",                                                                 null: false
    t.decimal  "balance",                        precision: 8, scale: 2, default: 0.0, null: false
    t.decimal  "amount",                         precision: 8, scale: 2,               null: false
    t.decimal  "support_amount",                 precision: 8, scale: 2
    t.string   "memberships_amount_description"
    t.decimal  "memberships_amount",             precision: 8, scale: 2
    t.json     "memberships_amounts_data"
    t.decimal  "remaining_memberships_amount",   precision: 8, scale: 2
    t.decimal  "paid_memberships_amount",        precision: 8, scale: 2
    t.json     "isr_balance_data",                                       default: {},  null: false
    t.datetime "sent_at"
    t.json     "overdue_notices"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "pdf"
    t.decimal  "isr_balance",                    precision: 8, scale: 2, default: 0.0, null: false
    t.decimal  "manual_balance",                 precision: 8, scale: 2, default: 0.0, null: false
    t.text     "note"
    t.string   "member_billing_interval",                                              null: false
  end

  add_index "invoices", ["member_id"], name: "index_invoices_on_member_id", using: :btree

  create_table "members", force: :cascade do |t|
    t.string   "emails",                     limit: 255
    t.string   "phones",                     limit: 255
    t.string   "address",                    limit: 255
    t.string   "zip",                        limit: 255
    t.string   "city",                       limit: 255
    t.string   "token",                      limit: 255,                 null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "first_name",                 limit: 255,                 null: false
    t.string   "last_name",                  limit: 255,                 null: false
    t.boolean  "support_member",                                         null: false
    t.datetime "waiting_started_at"
    t.string   "billing_interval",           limit: 255,                 null: false
    t.text     "food_note"
    t.text     "note"
    t.integer  "validator_id"
    t.datetime "validated_at"
    t.boolean  "gribouille"
    t.integer  "waiting_basket_id"
    t.integer  "waiting_distribution_id"
    t.boolean  "salary_basket",                          default: false
    t.string   "delivery_address",           limit: 255
    t.string   "delivery_zip",               limit: 255
    t.string   "delivery_city",              limit: 255
    t.datetime "inscription_submitted_at"
    t.datetime "deleted_at"
    t.datetime "welcome_email_sent_at"
    t.integer  "old_old_invoice_identifier"
  end

  add_index "members", ["deleted_at"], name: "index_members_on_deleted_at", using: :btree
  add_index "members", ["inscription_submitted_at"], name: "index_members_on_inscription_submitted_at", using: :btree
  add_index "members", ["old_old_invoice_identifier"], name: "index_members_on_old_old_invoice_identifier", using: :btree
  add_index "members", ["waiting_basket_id"], name: "index_members_on_waiting_basket_id", using: :btree
  add_index "members", ["waiting_distribution_id"], name: "index_members_on_waiting_distribution_id", using: :btree
  add_index "members", ["waiting_started_at"], name: "index_members_on_waiting_started_at", using: :btree
  add_index "members", ["welcome_email_sent_at"], name: "index_members_on_welcome_email_sent_at", using: :btree

  create_table "memberships", force: :cascade do |t|
    t.integer  "basket_id",                                          null: false
    t.integer  "distribution_id",                                    null: false
    t.integer  "member_id",                                          null: false
    t.decimal  "halfday_works_annual_price", precision: 8, scale: 2
    t.integer  "annual_halfday_works"
    t.date     "started_on",                                         null: false
    t.date     "ended_on",                                           null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "note"
    t.datetime "deleted_at"
  end

  add_index "memberships", ["basket_id"], name: "index_memberships_on_basket_id", using: :btree
  add_index "memberships", ["deleted_at"], name: "index_memberships_on_deleted_at", using: :btree
  add_index "memberships", ["distribution_id"], name: "index_memberships_on_distribution_id", using: :btree
  add_index "memberships", ["ended_on"], name: "index_memberships_on_ended_on", using: :btree
  add_index "memberships", ["member_id"], name: "index_memberships_on_member_id", using: :btree
  add_index "memberships", ["started_on"], name: "index_memberships_on_started_on", using: :btree

  create_table "old_invoices", force: :cascade do |t|
    t.integer  "member_id",                          null: false
    t.date     "date",                               null: false
    t.text     "number",                             null: false
    t.decimal  "amount",     precision: 8, scale: 2, null: false
    t.decimal  "balance",    precision: 8, scale: 2, null: false
    t.hstore   "data",                               null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "old_invoices", ["member_id"], name: "index_old_invoices_on_member_id", using: :btree
  add_index "old_invoices", ["number"], name: "index_old_invoices_on_number", using: :btree

end
