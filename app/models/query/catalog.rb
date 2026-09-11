# frozen_string_literal: true

module Query
  class Catalog
    ROUTES = [
      {
        method: "GET",
        path: "/",
        params: {},
        one_liner: "Route catalog and token tenant allowlist."
      },
      {
        method: "GET",
        path: "/:tenant/schema",
        params: { tenant: "Tenant slug (path)." },
        one_liner: "Tables on this tenant (sqlite_/pragma_/_litestream_ omitted)."
      },
      {
        method: "GET",
        path: "/:tenant/schema/:table",
        params: { tenant: "Tenant slug (path).", table: "Table name." },
        one_liner: "Columns, indexes, enums, associations. Denied columns omitted."
      },
      {
        method: "GET",
        path: "/:tenant/models",
        params: { tenant: "Tenant slug (path)." },
        one_liner: "ActiveRecord models and associations (denied tables skipped)."
      },
      {
        method: "POST",
        path: "/:tenant/sql",
        params: {
          tenant: "Tenant slug (path).",
          sql: "SELECT / WITH (JSON body).",
          page: "Page (default 1).",
          per: "Rows per page (default 100, max 500)."
        },
        one_liner: "Read-only SELECT. Organization api_token and calendar token denied. People rows allowed."
      },
      {
        method: "POST",
        path: "/:tenant/explain",
        params: { tenant: "Tenant slug (path).", sql: "SELECT / WITH (JSON body)." },
        one_liner: "SQLite EXPLAIN QUERY PLAN. Not bytecode EXPLAIN."
      },
      {
        method: "GET",
        path: "/:tenant/blobs/:id",
        params: { tenant: "Tenant slug (path).", id: "active_storage_blobs.id." },
        one_liner: "Stream blob bytes. SQL finds the row; this fetches the file. Not a signed URL."
      }
    ].freeze
  end
end
