# frozen_string_literal: true

# Patch ActiveAdmin's CSV export to use cursor-based batching instead of
# OFFSET-based pagination.
#
# The default implementation uses Kaminari pagination which generates slow queries like:
#   SELECT ... LIMIT 1000 OFFSET 72000
# These get progressively slower as offset increases (O(n) per page).
#
# This patch uses Rails' find_each with cursor-based batching which uses:
#   SELECT ... WHERE id > last_id ORDER BY id LIMIT 1000
# This is O(1) regardless of how deep into the dataset we are.
Rails.application.config.after_initialize do
  ActiveAdmin::ResourceController.class_eval do
    def in_paginated_batches(&block)
      collection.reorder(:id).find_each(batch_size: 1000) do |resource|
        yield apply_decorator(resource)
      end
    end
  end
end
