# frozen_string_literal: true

class MoveReminderDelaysToMailTemplates < ActiveRecord::Migration[8.1]
  def up
    rename_column :mail_templates, :remind_before_days, :delay_in_days

    copy_optional_delay("membership_renewal_reminder", "open_renewal_reminder_sent_after_in_days", 14)
    copy_optional_delay("bidding_round_opened_reminder", "open_bidding_round_reminder_sent_after_in_days", 7)
    set_delay("invoice_overdue_notice", 35)
    copy_weeks("absence_included_reminder")
    set_delay("activity_participation_reminder", 3)
    execute <<~SQL
      UPDATE mail_templates
      SET delay_in_days = 30
      WHERE title = 'price_reduction_card_expiring' AND delay_in_days IS NULL
    SQL

    remove_column :organizations, :open_renewal_reminder_sent_after_in_days
    remove_column :organizations, :open_bidding_round_reminder_sent_after_in_days
    remove_column :organizations, :absences_included_reminder_weeks_before
  end

  def down
    add_column :organizations, :open_renewal_reminder_sent_after_in_days, :integer
    add_column :organizations, :open_bidding_round_reminder_sent_after_in_days, :integer
    add_column :organizations, :absences_included_reminder_weeks_before, :integer, default: 4, null: false
    rename_column :mail_templates, :delay_in_days, :remind_before_days
  end

  private

  # Blank org days means the reminder is off today. Deactivate before writing
  # a default, or an active-by-default template would start sending.
  def copy_optional_delay(title, column, default)
    value = select_value("SELECT #{column} FROM organizations LIMIT 1")
    if value.nil?
      execute "UPDATE mail_templates SET active = 0, delay_in_days = #{default.to_i} WHERE title = #{quote(title)}"
    else
      execute "UPDATE mail_templates SET delay_in_days = #{value.to_i} WHERE title = #{quote(title)}"
    end
  end

  def set_delay(title, days)
    execute "UPDATE mail_templates SET delay_in_days = #{days.to_i} WHERE title = #{quote(title)}"
  end

  def copy_weeks(title)
    weeks = select_value("SELECT absences_included_reminder_weeks_before FROM organizations LIMIT 1")
    set_delay(title, (weeks || 4).to_i * 7)
  end
end
