# frozen_string_literal: true

class CreatePriceReductions < ActiveRecord::Migration[8.1]
  def up
    create_table :price_reduction_cards do |t|
      t.json :names, null: false, default: {}
      t.boolean :require_name, null: false, default: true
      t.boolean :require_number, null: false, default: true
      t.boolean :require_expires_on, null: false, default: true
      t.timestamps
    end

    create_table :price_reductions do |t|
      t.json :names, null: false, default: {}
      t.json :form_details, null: false, default: {}
      t.decimal :percentage, precision: 5, scale: 2
      t.decimal :fixed_amount, precision: 8, scale: 2
      t.decimal :cap_amount, precision: 8, scale: 2
      t.string :cap_mode, null: false, default: "once"
      t.boolean :renew, null: false, default: false
      t.json :depot_ids, null: false, default: []
      t.references :price_reduction_card, foreign_key: true
      t.boolean :visible, null: false, default: true
      t.integer :member_order_priority, null: false, default: 1
      t.datetime :discarded_at
      t.timestamps
    end

    # Appended so a schema dump keeps the same column order as a followed add_column.
    add_column :price_reductions, :public_names, :json, null: false, default: {}

    add_check_constraint :price_reductions,
      "cap_mode IN ('once', 'fiscal_year')",
      name: "price_reductions_cap_mode"
    add_check_constraint :price_reductions,
      "JSON_TYPE(depot_ids) = 'array'",
      name: "price_reductions_depot_ids_is_array"
    add_check_constraint :price_reductions,
      "(percentage IS NULL) <> (fixed_amount IS NULL)",
      name: "price_reductions_percentage_xor_fixed_amount"

    create_table :member_cards do |t|
      t.references :member, null: false, foreign_key: true
      t.references :price_reduction_card, null: false, foreign_key: true
      t.string :name
      t.string :number
      t.date :expires_on
      t.date :expiration_notice_sent_on
      t.timestamps
    end

    add_index :member_cards, [ :member_id, :price_reduction_card_id ], unique: true

    create_table :membership_price_reductions do |t|
      t.references :membership, null: false, foreign_key: true, index: { unique: true }
      t.references :price_reduction, null: false, foreign_key: true
      t.decimal :percentage, precision: 5, scale: 2
      t.decimal :fixed_amount, precision: 8, scale: 2
      t.decimal :amount, precision: 8, scale: 2, null: false, default: "0.0"
      t.timestamps
    end

    add_check_constraint :membership_price_reductions,
      "(percentage IS NULL) <> (fixed_amount IS NULL)",
      name: "membership_price_reductions_percentage_xor_fixed_amount"

    add_reference :members, :waiting_price_reduction, foreign_key: { to_table: :price_reductions }

    add_column :mail_templates, :remind_before_days, :integer
    insert_card_expiring_template
  end

  def down
    execute "DELETE FROM mail_templates WHERE title = 'price_reduction_card_expiring'"
    remove_column :mail_templates, :remind_before_days
    remove_reference :members, :waiting_price_reduction, foreign_key: { to_table: :price_reductions }
    drop_table :membership_price_reductions
    drop_table :member_cards
    drop_table :price_reductions
    drop_table :price_reduction_cards
  end

  private

  # Insert on the migration connection. A model write would open another
  # SQLite connection and lock, and under migrate_all it can hit the wrong tenant.
  def insert_card_expiring_template
    return if select_value("SELECT 1 FROM mail_templates WHERE title = 'price_reduction_card_expiring'")

    now = quote(Time.current)
    execute(<<~SQL)
      INSERT INTO mail_templates
        (title, active, subjects, contents, remind_before_days, created_at, updated_at)
      VALUES (
        'price_reduction_card_expiring',
        1,
        #{quote(card_expiring_subjects.to_json)},
        #{quote(card_expiring_contents.to_json)},
        #{MailTemplate::CARD_EXPIRING_REMIND_BEFORE_DAYS},
        #{now},
        #{now}
      )
    SQL
  end

  def card_expiring_subjects
    Organization.languages.index_with { |locale|
      I18n.with_locale(locale) {
        I18n.t("mail_template.default_subjects.price_reduction_card_expiring")
      }
    }
  end

  def card_expiring_contents
    Organization.languages.index_with { |locale|
      LiquidErb.render("mail_templates/price_reduction_card_expiring", locale: locale).strip + "\n"
    }
  end
end
