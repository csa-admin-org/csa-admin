# frozen_string_literal: true

require "json"

namespace :ebics do
  namespace :onboarding do
    desc "Print sanitized EBICS onboarding status (TENANT required; optional BANK_CONNECTION_ID; no live bank calls)"
    task status: :environment do
      print_ebics_json { ebics_task_runner.onboarding_status }
    end

    desc "Create encrypted H005 EBICS onboarding credentials (TENANT, URL, HOST_ID, CLIENT_ID, PARTICIPANT_ID, CONFIRM=true required; no live bank calls)"
    task initialize: :environment do
      print_ebics_json { ebics_task_runner.onboarding_initialize }
    end

    desc "Write printable EBICS initialization letter PDF (TENANT required; optional BANK_CONNECTION_ID, LOCALE, OUTPUT; no live bank calls)"
    task letter: :environment do
      print_ebics_json { ebics_task_runner.onboarding_letter }
    end

    desc "Submit EBICS INI setup order (TENANT, CONFIRM=true required; optional BANK_CONNECTION_ID; live bank call)"
    task submit_ini: :environment do
      print_ebics_json { ebics_task_runner.onboarding_submit_ini }
    end

    desc "Submit EBICS HIA setup order (TENANT, CONFIRM=true required; optional BANK_CONNECTION_ID; live bank call)"
    task submit_hia: :environment do
      print_ebics_json { ebics_task_runner.onboarding_submit_hia }
    end

    desc "Fetch HPB bank keys, verify finalized credentials with HTD, and mark connection ready (TENANT, CONFIRM=true required; optional BANK_CONNECTION_ID; live bank calls)"
    task finalize: :environment do
      print_ebics_json { ebics_task_runner.onboarding_finalize }
    end
  end

  namespace :sepa_direct_debit do
    desc "Allow retry after the bank confirms an uncertain upload was not accepted (TENANT, INVOICE_ID, CONFIRM=true, BANK_CONFIRMED_NOT_ACCEPTED=true required; no live bank call)"
    task confirm_not_accepted: :environment do
      print_ebics_json { ebics_task_runner.sepa_direct_debit_confirm_not_accepted }
    end
  end

  namespace :key_rotation do
    desc "Print sanitized EBICS key-rotation readiness inventory (optional TENANT=ragedevert; no live bank calls)"
    task readiness: :environment do
      print_ebics_json { ebics_task_runner.key_rotation_readiness }
    end

    desc "Prepare encrypted pending 4096-bit EBICS participant keys (TENANT and CONFIRM=true required; no live bank calls)"
    task prepare: :environment do
      print_ebics_json { ebics_task_runner.key_rotation_prepare }
    end

    desc "Validate local EBICS key-rotation request-build prerequisites (TENANT required; sanitized metadata only)"
    task validate: :environment do
      print_ebics_json { ebics_task_runner.key_rotation_validate }
    end

    desc "Alias for ebics:key_rotation:validate"
    task build: :environment do
      print_ebics_json { ebics_task_runner.key_rotation_validate }
    end

    desc "Submit pending EBICS HCS key rotation to the bank (TENANT and CONFIRM=true required; live bank call)"
    task submit: :environment do
      print_ebics_json { ebics_task_runner.key_rotation_submit }
    end

    desc "Verify pending EBICS keys with HTD (TENANT and CONFIRM=true required; live bank call, no credential promotion)"
    task verify: :environment do
      print_ebics_json { ebics_task_runner.key_rotation_verify }
    end

    desc "Promote verified pending EBICS keys locally (TENANT and CONFIRM=true required; no live bank call)"
    task promote: :environment do
      print_ebics_json { ebics_task_runner.key_rotation_promote }
    end

    desc "Prepare, submit, verify, and promote EBICS HCS key rotation (TENANT and CONFIRM=true required; live bank calls)"
    task perform: :environment do
      print_ebics_json { ebics_task_runner.key_rotation_perform }
    end

    desc "Discard pending EBICS key rotation without changing active keys (TENANT and CONFIRM=true required; no live bank call)"
    task discard_pending: :environment do
      print_ebics_json { ebics_task_runner.key_rotation_discard_pending }
    end

    desc "Purge retained previous EBICS key rotation blob (TENANT and CONFIRM=true required; no live bank call)"
    task purge_previous: :environment do
      print_ebics_json { ebics_task_runner.key_rotation_purge_previous }
    end

    namespace :batch do
      desc "Plan EBICS key rotation for selected tenants (optional TENANTS=..., PROVIDER=RAIFCHEC/ebics; no live bank calls)"
      task plan: :environment do
        print_ebics_json { ebics_task_runner.key_rotation_batch_plan }
      end

      desc "Prepare pending EBICS keys for selected tenants (TENANTS=..., PROVIDER=..., or ALL=true; CONFIRM=true required; no live bank calls)"
      task prepare: :environment do
        print_ebics_json { ebics_task_runner.key_rotation_batch_prepare }
      end

      desc "Prepare, submit, verify, and promote EBICS keys for one tenant (TENANT=... and CONFIRM=true required; live bank calls)"
      task perform: :environment do
        print_ebics_json { ebics_task_runner.key_rotation_batch_perform }
      end
    end
  end

  desc "Print sanitized EBICS 3.0/H005 readiness report (optional TENANT=ragedevert; no live bank calls)"
  task readiness: :environment do
    print_ebics_json { ebics_task_runner.readiness }
  end

  desc "Run EBICS capabilities monitor and print health summary (optional TENANT=ragedevert; live bank calls)"
  task monitor: :environment do
    print_ebics_json { ebics_task_runner.monitor }
  end

  desc "Print sanitized H005 EBICS capabilities using HTD/HAA (TENANT required; live bank calls)"
  task capabilities: :environment do
    print_ebics_json { ebics_task_runner.capabilities }
  end

  desc "Run a manual H005/BTF payment download test (TENANT, FROM, TO required; ACK=true acknowledges returned data)"
  task btf_download: :environment do
    print_ebics_json { ebics_task_runner.btf_download }
  end

  def ebics_task_runner
    Billing::EBICS::TaskRunner.new
  end

  def print_ebics_json
    puts JSON.pretty_generate(yield)
  rescue Billing::EBICS::UnsupportedOperation => e
    abort e.message
  end
end
