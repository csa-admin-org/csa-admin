# frozen_string_literal: true

require "test_helper"

class RecurringScheduleTest < ActiveSupport::TestCase
  test "clears finished Solid Queue jobs globally on the low queue" do
    cleanup = production_tasks.fetch("clear_solid_queue_finished_jobs")

    assert_equal "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)", cleanup.fetch("command")
    assert_equal "low", cleanup.fetch("queue")
    assert_equal "every hour at minute 12", cleanup.fetch("schedule")
  end

  test "every production task uses the low queue" do
    production_tasks.each do |name, task|
      assert_equal "low", task["queue"], "#{name} should use the low queue"
    end
  end

  private

  def production_tasks
    YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch("production")
  end
end
