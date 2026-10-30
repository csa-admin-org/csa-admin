# frozen_string_literal: true

# kaminari-core 1.3.0/1.3.1 calls LookupContext#find_template, which Rails 8.2
# removed (it was an alias of #find). Introduced in kaminari/kaminari@c5cc1a1;
# no upstream issue or fix as of 2026-10-29. Drop this once Kaminari calls #find.
Rails.application.config.to_prepare do
  ActionView::LookupContext.class_eval do
    alias_method :find_template, :find unless method_defined?(:find_template)
  end
end
