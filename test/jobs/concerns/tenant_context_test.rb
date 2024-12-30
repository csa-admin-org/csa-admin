# frozen_string_literal: true

require "test_helper"

class TenantContextTest < ActiveJob::TestCase
  class DummyJob < ActiveJob::Base
    include TenantContext
    def perform(admin, name: nil)
      admin.update!(name: name)
    end
  end

  class DummyExceptionJob < ActiveJob::Base
    include TenantContext
    retry_on Exception, wait: :polynomially_longer, attempts: 2

    def perform(foo)
      raise Exception
    end
  end

  test "add current attributes and tenant last arguments" do
    admin = admins(:super)
    Current.session = create_session(admin)
    DummyJob.perform_later(admin, name: "Admin!")

    assert_equal 1, enqueued_jobs.size
    job = enqueued_jobs.first
    assert_equal [
      { "_aj_globalid" => "gid://csa-admin/Admin/#{admin.id}" },
      { "name" => "Admin!", "_aj_ruby2_keywords" => [ "name" ] },
      {
        "tenant" => "acme",
        "current" => { "session" => { "_aj_globalid" => "gid://csa-admin/Session/#{Current.session.id}" }, "_aj_symbol_keys" => [ "session" ] }, "_aj_symbol_keys" => []
      }
    ], job["arguments"]

    perform_enqueued_jobs
    assert_equal 0, enqueued_jobs.size
    assert_equal "Admin!", admin.reload.name
  end

  test "retry with the same current attributes and tenant last arguments" do
    Current.session = create_session(admins(:super))
    DummyExceptionJob.perform_later("bar")

    assert_equal 1, enqueued_jobs.size
    job = enqueued_jobs.first
    assert_equal [
      "bar",
      {
        "tenant" => "acme",
        "current" => { "session" => { "_aj_globalid" => "gid://csa-admin/Session/#{Current.session.id}" }, "_aj_symbol_keys" => [ "session" ] }, "_aj_symbol_keys" => []
      }
    ], job["arguments"]

    # rescue Exception one time
    perform_enqueued_jobs

    assert_equal 1, enqueued_jobs.size
    job = enqueued_jobs.first
    assert_equal [
      "bar",
      {
        "tenant" => "acme",
        "current" => { "session" => { "_aj_globalid" => "gid://csa-admin/Session/#{Current.session.id}" }, "_aj_symbol_keys" => [ "session" ] }, "_aj_symbol_keys" => []
      }
    ], job["arguments"]

    assert_raises(Exception) { perform_enqueued_jobs }
    assert_equal 0, enqueued_jobs.size
  end
end
