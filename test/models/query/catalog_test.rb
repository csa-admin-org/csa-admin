# frozen_string_literal: true

require "test_helper"

class Query::CatalogTest < ActiveSupport::TestCase
  test "every catalog path is drawn under the query subdomain" do
    paths = Rails.application.routes.routes.filter_map { |route|
      next unless route.defaults[:controller]&.start_with?("query/")

      path = route.path.spec.to_s.delete_suffix("(.:format)")
      path = path.chomp("/")
      path.empty? ? "/" : path
    }

    Query::Catalog::ROUTES.each do |entry|
      assert_includes paths, entry[:path], "missing route #{entry[:path]}"
    end
    paths.each do |path|
      assert Query::Catalog::ROUTES.any? { |entry| entry[:path] == path },
        "undocumented route #{path}"
    end
  end
end
