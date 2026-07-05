# frozen_string_literal: true

require "terminal-table"

class Billing::HealthReport
  HEALTH_EMOJI = {
    "healthy" => "🟢",
    "warning" => "🟡",
    "unknown" => "⚪",
    "errored" => "🔴"
  }.freeze

  def initialize(tenant_names: nil, provider: nil, now: Time.current)
    @tenant_names = Array(tenant_names).compact_blank
    @provider = provider.presence
    @now = now
  end

  def rows
    selected_tenant_names.filter_map do |tenant|
      row = nil
      Tenant.switch(tenant) do
        row = row_for(tenant)
      end
      row
    end
  end

  def table
    Terminal::Table.new(
      title: "Billing health — #{now.strftime("%Y-%m-%d %H:%M")}",
      headings: [ "Tenant", "Bank", "Health", "Last import", "Version", "Security", "Notes" ],
      rows: rows.map { |row| table_row(row) })
  end

  private

  attr_reader :tenant_names, :provider, :now

  def selected_tenant_names
    tenant_names.presence || Tenant.all
  end

  def row_for(tenant)
    connection = Current.org.active_bank_connection
    return missing_connection_row(tenant) unless connection
    return if provider && !provider_matches?(connection)

    {
      tenant: tenant,
      bank: bank_label(connection),
      health: health_label(connection),
      last_import: last_import_label(connection),
      version: version_label(connection),
      security: security_label(connection),
      notes: notes_label(connection)
    }
  end

  def missing_connection_row(tenant)
    return if provider

    {
      tenant: tenant,
      bank: "—",
      health: "🔴 missing",
      last_import: "—",
      version: "—",
      security: "—",
      notes: "No active bank connection"
    }
  end

  def table_row(row)
    [
      row.fetch(:tenant),
      row.fetch(:bank),
      row.fetch(:health),
      row.fetch(:last_import),
      row.fetch(:version),
      row.fetch(:security),
      row.fetch(:notes)
    ]
  end

  def bank_label(connection)
    [ connection.provider, connection.name ].compact_blank.join(" / ")
  end

  def health_label(connection)
    status = connection.health_status.to_s
    "#{HEALTH_EMOJI.fetch(status, "⚪")} #{status.presence || "unknown"}"
  end

  def last_import_label(connection)
    if connection.last_import_succeeded_at
      "ok #{date(connection.last_import_succeeded_at)}"
    elsif connection.last_no_data_at
      "no data #{date(connection.last_no_data_at)}"
    elsif connection.last_import_attempted_at
      "attempt #{date(connection.last_import_attempted_at)}"
    else
      "—"
    end
  end

  def version_label(connection)
    case connection.provider
    when "ebics"
      "EBICS #{connection.settings.to_h.deep_stringify_keys["protocol"].presence || "?"}"
    when "bas"
      "BAS keyfile"
    when "bunq"
      "bunq API"
    when "mock"
      "Mock"
    else
      connection.provider
    end
  end

  def security_label(connection)
    return "—" unless connection.ebics?

    summary = connection.ebics_key_summary
    return "error" if summary.dig("error").present?

    summary["participant_key_min_bits"].presence&.to_s || "—"
  end

  def notes_label(connection)
    notes = []
    notes << key_rotation_note(connection) if connection.ebics?
    notes << connection.last_error_class if connection.last_error_class.present?
    notes.compact_blank.join("; ").presence || "—"
  end

  def provider_matches?(connection)
    provider_filter = provider.downcase
    provider_candidates(connection).any? { |candidate| candidate.to_s.downcase == provider_filter }
  end

  def provider_candidates(connection)
    credentials = connection.credentials.to_h.deep_stringify_keys
    [ connection.provider, connection.name, credentials["host_id"] ].compact_blank
  end

  def key_rotation_note(connection)
    details = connection.status_details.to_h.deep_stringify_keys.fetch("key_rotation") { {} }
    state = details["state"].presence
    return unless state

    case state
    when "rotated"
      nil
    when "rotation_failed"
      hcs_failed_note(connection)
    when "pending_rotation"
      "HCS pending"
    else
      state
    end
  end

  def hcs_failed_note(connection)
    kept_bits = security_label(connection)
    return "HCS failed" if kept_bits.in?([ "—", "error" ])

    "HCS failed; kept #{kept_bits}"
  end

  def date(value)
    value.in_time_zone.strftime("%Y-%m-%d")
  end
end
