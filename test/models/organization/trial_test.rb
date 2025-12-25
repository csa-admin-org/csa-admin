# frozen_string_literal: true

require "test_helper"

class Organization::TrialTest < ActiveSupport::TestCase
  test "trial_baskets? returns true when trial_baskets_count is positive" do
    org(trial_baskets_count: 2)

    assert Current.org.trial_baskets?
  end

  test "trial_baskets? returns false when trial_baskets_count is zero" do
    org(trial_baskets_count: 0)

    assert_not Current.org.trial_baskets?
  end

  test "validates trial_baskets_count is not negative" do
    Current.org.trial_baskets_count = -1

    assert_not Current.org.valid?
    assert_includes Current.org.errors[:trial_baskets_count], "must be greater than or equal to 0"
  end

  test "validates trial_baskets_count presence" do
    Current.org.trial_baskets_count = nil

    assert_not Current.org.valid?
    assert_includes Current.org.errors[:trial_baskets_count], "can't be blank"
  end
end
