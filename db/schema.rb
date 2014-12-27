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

ActiveRecord::Schema.define(version: 20141227171339) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_admin_comments", force: true do |t|
    t.string   "namespace"
    t.text     "body"
    t.string   "resource_id",   null: false
    t.string   "resource_type", null: false
    t.integer  "author_id"
    t.string   "author_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "active_admin_comments", ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id", using: :btree
  add_index "active_admin_comments", ["namespace"], name: "index_active_admin_comments_on_namespace", using: :btree
  add_index "active_admin_comments", ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id", using: :btree

  create_table "admins", force: true do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "admins", ["email"], name: "index_admins_on_email", unique: true, using: :btree
  add_index "admins", ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true, using: :btree

  create_table "baskets", force: true do |t|
    t.string   "name",                                         null: false
    t.integer  "year",                                         null: false
    t.decimal  "annual_price",         precision: 8, scale: 2, null: false
    t.integer  "annual_halfday_works",                         null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "deliveries", force: true do |t|
    t.date     "date",       null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "deliveries", ["date"], name: "index_deliveries_on_date", using: :btree

  create_table "distributions", force: true do |t|
    t.string   "name"
    t.string   "address"
    t.string   "zip"
    t.string   "city"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal  "basket_price", precision: 8, scale: 2, null: false
  end

  create_table "halfday_works", force: true do |t|
    t.integer  "member_id",                      null: false
    t.date     "date",                           null: false
    t.string   "periods",                        null: false, array: true
    t.datetime "validated_at"
    t.integer  "validator_id"
    t.integer  "participants_count", default: 1, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "rejected_at"
  end

  add_index "halfday_works", ["date"], name: "index_halfday_works_on_date", using: :btree
  add_index "halfday_works", ["member_id"], name: "index_halfday_works_on_member_id", using: :btree
  add_index "halfday_works", ["rejected_at"], name: "index_halfday_works_on_rejected_at", using: :btree
  add_index "halfday_works", ["validated_at"], name: "index_halfday_works_on_validated_at", using: :btree
  add_index "halfday_works", ["validator_id"], name: "index_halfday_works_on_validator_id", using: :btree

  create_table "members", force: true do |t|
    t.string   "emails"
    t.string   "phones"
    t.string   "address"
    t.string   "zip"
    t.string   "city"
    t.string   "token",                            null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "first_name",                       null: false
    t.string   "last_name",                        null: false
    t.boolean  "support_member",                   null: false
    t.datetime "waiting_from"
    t.string   "billing_interval",                 null: false
    t.text     "food_note"
    t.text     "note"
    t.integer  "validator_id"
    t.datetime "validated_at"
    t.boolean  "gribouille",       default: false, null: false
  end

  create_table "memberships", force: true do |t|
    t.integer  "basket_id",                                    null: false
    t.integer  "distribution_id",                              null: false
    t.integer  "member_id",                                    null: false
    t.integer  "billing_member_id"
    t.decimal  "annual_price",         precision: 8, scale: 2
    t.integer  "annual_halfday_works"
    t.date     "started_on",                                   null: false
    t.date     "ended_on",                                     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "memberships", ["basket_id"], name: "index_memberships_on_basket_id", using: :btree
  add_index "memberships", ["billing_member_id"], name: "index_memberships_on_billing_member_id", using: :btree
  add_index "memberships", ["distribution_id"], name: "index_memberships_on_distribution_id", using: :btree
  add_index "memberships", ["ended_on"], name: "index_memberships_on_ended_on", using: :btree
  add_index "memberships", ["member_id"], name: "index_memberships_on_member_id", using: :btree
  add_index "memberships", ["started_on"], name: "index_memberships_on_started_on", using: :btree

end
