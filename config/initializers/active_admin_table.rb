# frozen_string_literal: true

# Add filters stimulus controller for live fitlering
ActiveAdmin.before_load do |app|
  module ActiveAdmin
    module Views
      class TableFor < Arbre::HTML::Table
        def build_table_body
          # table_row stimulus controller overwrite
          @tbody_html ||= {}
          unless @tbody_html.dig(:data, :controller)
            table_row_controller = true
            @tbody_html.deep_merge!(data: { controller: "table-row" })
          end

          @tbody = tbody **@tbody_html do
            # Build enough rows for our collection
            @collection.each do |elem|
              html_options = @row_html&.call(elem) || {}
              html_options.reverse_merge!(class: @row_class&.call(elem))

              if table_row_controller
                html_options.deep_merge!(
                  data: {
                    "table-row-target": "row",
                    action: %w[
                      click->table-row#navigate
                      keydown->table-row#handleKeydown
                    ].join(" ")
                  },
                  tabindex: 0)
              end

              tr(id: dom_id_for(elem), **html_options)
            end
          end
        end
      end
    end
  end
end
