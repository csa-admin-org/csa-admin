# frozen_string_literal: true

# `bin/rails herb:check` compiles every HTML+ERB template on every view path,
# including a gem copy that Action View never renders once the app overrides
# it. Skip a later copy of a virtual path the app (or an earlier engine)
# already provides, so the check matches what gets compiled.
#
# The gem layout is the only template that renders active_admin/main_navigation.
# app/views/layouts/active_admin.html.erb replaces that layout and does not
# render the partial, so Action View never compiles it. The gem source puts
# ERB in an attribute name, which Herb rejects.
require "action_view/herb_checker"

module HerbCheckSkipsShadowedTemplates
  UNRENDERED_VIRTUAL_PATHS = %w[active_admin/_main_navigation].freeze

  def check(view_paths)
    super(shadowing_resolvers(view_paths))
  end

  private
  def shadowing_resolvers(view_paths)
    seen = {}
    view_paths.map { |resolver| ShadowingResolver.new(resolver, seen) }
  end

  class ShadowingResolver < SimpleDelegator
    def initialize(resolver, seen)
      super(resolver)
      @seen = seen
    end

    def all_unbound_templates
      __getobj__.all_unbound_templates.reject { |template|
        virtual_path = template.virtual_path.to_s
        next false if virtual_path.empty?
        next true if UNRENDERED_VIRTUAL_PATHS.include?(virtual_path)

        @seen.key?(virtual_path).tap { @seen[virtual_path] = true }
      }
    end

    def eql?(other)
      equal?(other)
    end
    alias_method :==, :eql?

    def hash
      object_id.hash
    end
  end
end

ActionView::HerbChecker.singleton_class.prepend(HerbCheckSkipsShadowedTemplates)
