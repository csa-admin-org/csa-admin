# frozen_string_literal: true

# Filter patch for ActiveSupport::ContinuousIntegration.
# Upstream already runs groups. This only adds --group/--step until
# rails/rails#58333. Parallel groups collect steps in TaskCollector, so
# a wrapper on ContinuousIntegration#step is not enough. Delete this file
# and the require in bin/ci when that PR ships.

require "active_support/continuous_integration"
require "optparse"

module ActiveSupport
  class ContinuousIntegration
    module GroupStepFilter
      FILTER_KEY = :csa_admin_ci_filter

      def initialize
        super
        @groups = []
        @steps = []
        @group_selected = false
        @show_help = false
      end

      def run(title, subtitle, &block)
        options = parse_options
        return puts(options) if @show_help

        super(title, subtitle) do
          instance_eval(&block)
          ensure_steps_ran!
        end
      end

      def step(title, *command)
        return unless selected_step?(title, group_selected: @group_selected)

        super
      end

      # Sequential groups use #step. Parallel groups collect on this thread,
      # then run nested groups on a worker, so the stored block must carry
      # the selection.
      def group(name, parallel: 1, &block)
        selected = selected_group?(name, parent_selected: @group_selected)
        if parallel <= 1
          within_group(selected) { super(name, parallel: parallel, &block) }
        else
          super(name, parallel: parallel, &filter_block(selected, &block))
        end
      end

      def selected_group?(name, parent_selected:)
        parent_selected || @groups.empty? || selected?(@groups, name)
      end

      def selected_step?(name, group_selected:)
        (@groups.empty? || group_selected) && (@steps.empty? || selected?(@steps, name))
      end

      private
      def parse_options
        @groups = []
        @steps = []
        @show_help = false

        parser = OptionParser.new do |options|
          options.banner = "Usage: bin/ci [options]"
          options.on("-g", "--group NAME", "Run all steps in the named group (case-insensitive).") { |option| @groups << option }
          options.on("-s", "--step NAME", "Run the named step (case-insensitive).") { |option| @steps << option }
          options.on("-f", "--fail-fast", "Abort after the first failure.")
          options.on("-h", "--help", "Show this help.") { @show_help = true }
        end
        parser.parse!(ARGV.dup)
        parser
      rescue OptionParser::ParseError => error
        abort "#{error.message}\n\n#{parser}"
      end

      def ensure_steps_ran!
        return unless filtered? && results.empty?

        abort colorize("No CI steps matched #{selection}.", :error)
      end

      def filtered?
        @groups.any? || @steps.any?
      end

      def selected?(names, candidate)
        names.any? { |name| candidate.to_s.casecmp?(name) }
      end

      def selection
        selectors = @groups.map { |group| "--group #{group.inspect}" }
        selectors.concat(@steps.map { |step| "--step #{step.inspect}" })
        selectors.join(" and ")
      end

      def within_group(group_selected)
        previous = @group_selected
        @group_selected = group_selected
        yield
      ensure
        @group_selected = previous
      end

      def filter_block(group_selected, &block)
        ci = self
        proc do
          previous = Thread.current[FILTER_KEY]
          Thread.current[FILTER_KEY] = { ci: ci, group_selected: group_selected }
          begin
            instance_eval(&block)
          ensure
            Thread.current[FILTER_KEY] = previous
          end
        end
      end
    end
    prepend GroupStepFilter

    class Group
      class TaskCollector
        module StepFilter
          def step(title, *command)
            context = Thread.current[GroupStepFilter::FILTER_KEY]
            return super unless context
            return unless context[:ci].selected_step?(title, group_selected: context[:group_selected])

            super
          end

          def group(name, **options, &block)
            context = Thread.current[GroupStepFilter::FILTER_KEY]
            return super unless context

            selected = context[:ci].selected_group?(name, parent_selected: context[:group_selected])
            super(name, **options, &filter_block(context[:ci], selected, &block))
          end

          private
          def filter_block(ci, group_selected, &block)
            proc do
              previous = Thread.current[GroupStepFilter::FILTER_KEY]
              Thread.current[GroupStepFilter::FILTER_KEY] = { ci: ci, group_selected: group_selected }
              begin
                instance_eval(&block)
              ensure
                Thread.current[GroupStepFilter::FILTER_KEY] = previous
              end
            end
          end
        end
        prepend StepFilter
      end
    end
  end
end
