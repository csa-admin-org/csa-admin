require "rails_helper"

describe TenantContext do
  specify "add current attributes and tenant last arguments" do
    class DummyJob < ActiveJob::Base
      include TenantContext
      def perform(admin, name: nil)
        admin.update!(name: name)
      end
    end

    admin = create(:admin, name: "Admin")
    Current.session = create(:session, id: 42)
    DummyJob.perform_later(admin, name: "Admin!")

    expect(enqueued_jobs.size).to eq(1)
    job = enqueued_jobs.first
    expect(job["arguments"]).to eq([
      { "_aj_globalid" => "gid://csa-admin/Admin/1" },
      { "name" => "Admin!", "_aj_ruby2_keywords" => [ "name" ] },
      {
        "tenant" => "acme",
        "current" => { "session" => { "_aj_globalid" => "gid://csa-admin/Session/42" }, "_aj_symbol_keys" => [ "session" ] }, "_aj_symbol_keys" => []
      }
    ])

    perform_enqueued_jobs
    expect(enqueued_jobs.size).to eq(0)
    expect(admin.reload.name).to eq("Admin!")
  end

  specify "retry with the same current attributes and tenant last arguments" do
    class DummyExceptionJob < ActiveJob::Base
      include TenantContext
      retry_on Exception, wait: :polynomially_longer, attempts: 2

      def perform(foo)
        raise Exception
      end
    end

    Current.session = create(:session, id: 42)
    DummyExceptionJob.perform_later("bar")

    expect(enqueued_jobs.size).to eq(1)
    job = enqueued_jobs.first
    expect(job["arguments"]).to eq([
      "bar",
      {
        "tenant" => "acme",
        "current" => { "session" => { "_aj_globalid" => "gid://csa-admin/Session/42" }, "_aj_symbol_keys" => [ "session" ] }, "_aj_symbol_keys" => []
      }
    ])

    # rescue Exception one time
    perform_enqueued_jobs

    expect(enqueued_jobs.size).to eq(1)
    job = enqueued_jobs.first
    expect(job["arguments"]).to eq([
      "bar",
      {
        "tenant" => "acme",
        "current" => { "session" => { "_aj_globalid" => "gid://csa-admin/Session/42" }, "_aj_symbol_keys" => [ "session" ] }, "_aj_symbol_keys" => []
      }
    ])

    begin
      perform_enqueued_jobs
    rescue Exception
    end
    expect(enqueued_jobs.size).to eq(0)
  end
end
