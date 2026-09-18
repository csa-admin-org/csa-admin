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
        method: "POST",
        path: "/tickets/search",
        params: {
          q: "Substring on subject and message body (JSON body).",
          tenant: "Optional slug or list. Intersect with the token allowlist.",
          per: "Max tickets (default 50, max 50)."
        },
        one_liner: "Support tickets across allowed live tenants. Sequential LIKE. Skip demo/custom. Objects with snippet."
      },
      {
        method: "GET",
        path: "/organizations",
        params: {
          attributes: "Comma-separated org settings (allowlisted).",
          tenant: "Optional slug or list. Intersect with the token allowlist."
        },
        one_liner: "Org settings across live tenants. Equality filters on allowlisted keys. Skip demo/custom."
      },
      {
        method: "GET",
        path: "/bank_connections",
        params: {
          provider: "ebics / bas / bunq / mock.",
          state: "draft / initializing / waiting_for_bank / ready / disabled / errored.",
          active: "true / false.",
          tenant: "Optional slug or list. Intersect with the token allowlist."
        },
        one_liner: "Bank connections across live tenants. No credentials. Skip demo/custom."
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
        one_liner: "Columns, indexes, enums, associations."
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
        one_liner: "Read-only SELECT. People rows allowed. Encrypted columns come back as ciphertext."
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
