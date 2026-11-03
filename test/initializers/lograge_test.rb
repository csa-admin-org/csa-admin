# frozen_string_literal: true

require "test_helper"

class LogrageTest < ActiveSupport::TestCase
  test "masks login and newsletter tokens in the logged path" do
    assert_equal "/sessions/[FILTERED]", logged_path("/sessions/login-token")
    assert_equal "/sessions/[FILTERED]", logged_path("/sessions/login-token?next=/members")
    assert_equal "/newsletters/unsubscribe/[FILTERED]", logged_path("/newsletters/unsubscribe/reuse-me")
    assert_equal "/newsletters/subscribe/[FILTERED]", logged_path("/newsletters/subscribe/reuse-me")
    assert_equal "/members/1", logged_path("/members/1")
  end

  private

  def logged_path(path)
    event = ActiveSupport::Notifications::Event.new(
      "process_action.action_controller",
      Time.current,
      Time.current,
      "id",
      { path: path, params: { controller: "sessions", action: "show", id: "login-token" } }
    )

    Rails.application.config.lograge.custom_options.call(event).fetch(:path)
  end
end
