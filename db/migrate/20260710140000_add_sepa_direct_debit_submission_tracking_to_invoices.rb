# frozen_string_literal: true

class AddSEPADirectDebitSubmissionTrackingToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :sepa_direct_debit_submission_state, :string
    add_column :invoices, :sepa_direct_debit_submission_attempted_at, :datetime
    add_column :invoices, :sepa_direct_debit_transaction_id, :string
    add_column :invoices, :sepa_direct_debit_pain_message_id, :string
    add_column :invoices, :sepa_direct_debit_pain_payload_sha256, :string

    add_check_constraint :invoices,
      "sepa_direct_debit_submission_state IS NULL OR sepa_direct_debit_submission_state IN ('submitting', 'submitted', 'uncertain', 'failed')",
      name: "invoices_sepa_direct_debit_submission_state"
  end
end
