# frozen_string_literal: true

ActiveAdmin.setup do |config|
  # == Site Title
  #
  # Set the title that is displayed on the main layout
  # for each of the active admin pages.
  #
  config.site_title = ->(view) { Current.acp.name }

  # == Default Namespace
  #
  # Set the default namespace each administration resource
  # will be added to.
  #
  # eg:
  #   config.default_namespace = :hello_world
  #
  # This will create resources in the HelloWorld module and
  # will namespace routes to /hello_world/*
  #
  # To set no namespace by default, use:
  #   config.default_namespace = false
  #
  # Default:
  # config.default_namespace = :admin
  #
  # You can customize the settings for each namespace by using
  # a namespace block. For example, to change the site title
  # within a namespace:
  #
  #   config.namespace :admin do |admin|
  #     admin.site_title = "Custom Admin Title"
  #   end
  #
  # This will ONLY change the title for the admin section. Other
  # namespaces will continue to use the main "site_title" configuration.
  config.default_namespace = false

  # == User Authentication
  #
  # Active Admin will automatically call an authentication
  # method in a before filter of all controller actions to
  # ensure that there is a currently logged in admin user.
  #
  # This setting changes the method which Active Admin calls
  # within the application controller.
  config.authentication_method = :authenticate_admin!

  # == User Authorization
  #
  # Active Admin will automatically call an authorization
  # method in a before filter of all controller actions to
  # ensure that there is a user with proper rights. You can use
  # CanCanAdapter or make your own. Please refer to documentation.
  config.authorization_adapter = ActiveAdmin::CanCanAdapter

  # In case you prefer Pundit over other solutions you can here pass
  # the name of default policy class. This policy will be used in every
  # case when Pundit is unable to find suitable policy.
  # config.pundit_default_policy = "MyDefaultPunditPolicy"

  # You can customize your CanCan Ability class name here.
  config.cancan_ability_class = "Ability"

  # You can specify a method to be called on unauthorized access.
  # This is necessary in order to prevent a redirect loop which happens
  # because, by default, user gets redirected to Dashboard. If user
  # doesn't have access to Dashboard, he'll end up in a redirect loop.
  # Method provided here should be defined in application_controller.rb.
  config.on_unauthorized_access = :access_denied

  # == Current User
  #
  # Active Admin will associate actions with the current
  # user performing them.
  #
  # This setting changes the method which Active Admin calls
  # (within the application controller) to return the currently logged in user.
  config.current_user_method = :current_admin

  # == Logging Out
  #
  # Active Admin displays a logout link on each screen. These
  # settings configure the location and method used for the link.
  #
  # This setting changes the path where the link points to. If it's
  # a string, the strings is used as the path. If it's a Symbol, we
  # will call the method to return the path.
  #
  # Default:
  config.logout_link_path = :logout_path

  # == Root
  #
  # Set the action to call for the root path. You can set different
  # roots for each namespace.
  #
  # Default:
  config.root_to = "dashboard#index"

  # == Admin Comments
  #
  # This allows your users to comment on any resource registered with Active Admin.
  #
  # You can completely disable comments:
  # config.comments = false
  #
  # You can change the name under which comments are registered:
  # config.comments_registration_name = 'AdminComment'
  #
  # You can change the order for the comments and you can change the column
  # to be used for ordering:
  # config.comments_order = 'created_at ASC'
  #
  # You can disable the menu item for the comments index page:
  # config.comments_menu = false
  #
  # You can customize the comment menu:
  # config.comments_menu = { parent: 'Admin', priority: 1 }
  config.comments = true
  config.comments_menu = false

  # == Batch Actions
  #
  # Enable and disable Batch Actions
  #
  config.batch_actions = false

  # == Controller Filters
  #
  # You can add before, after and around filters to all of your
  # Active Admin resources and pages from here.
  #
  # config.before_action :foo

  # == Localize Date/Time Format
  #
  # Set the localize format to display dates and times.
  # To understand how to localize your app with I18n, read more at
  # https://github.com/svenfuchs/i18n/blob/master/lib%2Fi18n%2Fbackend%2Fbase.rb#L52
  #
  # config.localize_format = :long

  # == Removing Breadcrumbs
  #
  # Breadcrumbs are enabled by default. You can customize them for individual
  # resources or you can disable them globally from here.
  #
  config.breadcrumb = true

  # == Create Another Checkbox
  #
  # Create another checkbox is disabled by default. You can customize it for individual
  # resources or you can enable them globally from here.
  #
  # config.create_another = true

  # == CSV options
  #
  # Set the CSV builder separator
  # config.csv_options = { :col_sep => ';' }
  #
  # Force the use of quotes
  # config.csv_options = { :force_quotes => true }

  # Fix encoding issue with Excel 2003 https://stackoverflow.com/questions/155097/microsoft-excel-mangles-diacritics-in-csv-files
  config.csv_options = { byte_order_mark: "\xEF\xBB\xBF" }

  # == Menu System
  #
  # You can add a navigation menu to be used in your application, or configure a provided menu
  #
  # To change the default utility navigation to show a link to your website & a logout btn
  #
  #   config.namespace :admin do |admin|
  #     admin.build_menu :utility_navigation do |menu|
  #       menu.add label: "My Great Website", url: "http://www.mygreatwebsite.com", html_options: { target: :blank }
  #       admin.add_logout_button_to_menu menu
  #     end
  #   end
  #
  # If you wanted to add a static menu item to the default menu provided:
  #
  config.namespace false do |admin|
    admin.build_menu do |menu|
      menu.add label: -> { I18n.t("active_admin.menu.shop") }, priority: 6, id: :navshop
      menu.add label: :activities_human_name, priority: 7
      menu.add label: -> { I18n.t("active_admin.menu.billing") }, priority: 9, id: :navbilling
      menu.add label: -> {
        icon "ellipsis-horizontal", class: "w-5 h-5", title: t("active_admin.settings")
      }, priority: 20, id: :other, html_options: { data: { controller: "menu-sorting" } }
    end

    # admin.build_menu :utility_navigation do |menu|
    #   admin.add_current_user_to_menu menu, 1
    #   admin.add_updates_notice_to_menu menu, 2
    #   admin.add_logout_button_to_menu menu, 3
    # end
  end

  # == Download Links
  #
  # You can disable download links on resource listing pages,
  # or customize the formats shown per namespace/globally
  #
  # To disable/customize for the :admin namespace:
  #
  #   config.namespace :admin do |admin|
  #
  #     # Disable the links entirely
  #     admin.download_links = false
  #
  #     # Only show XML & PDF options
  #     admin.download_links = [:xml, :pdf]
  #
  #     # Enable/disable the links based on block
  #     #   (for example, with cancan)
  #     admin.download_links = proc { can?(:view_download_links) }
  #
  #   end
  config.download_links = [ :csv ]
  # Streaming is causing issue with apartment DB schema.
  config.disable_streaming_in = %w[production development test]

  # == Pagination
  #
  # Pagination is enabled by default for all resources.
  # You can control the default per page count for all resources here.
  #
  config.default_per_page = 25
  #
  # You can control the max per page count too.
  #
  config.max_per_page = 10_000

  # == Filters
  #
  # By default the index screen includes a "Filters" sidebar on the right
  # hand side with a filter for each attribute of the registered model.
  # You can enable or disable them for all resources here.
  #
  # config.filters = true
  #
  # By default the filters include associations in a select, which means
  # that every record will be loaded for each association.
  # You can enabled or disable the inclusion
  # of those filters by default here.
  #
  # config.include_default_association_filters = true
  config.current_filters = false

  # == Sorting
  #
  # By default ActiveAdmin::OrderClause is used for sorting logic
  # You can inherit it with own class and inject it for all resources
  #
  # config.order_clause = MyOrderClause
end

Rails.application.reloader.to_prepare do
  class ActiveAdmin::ResourceDSL
    include ActionView::Helpers::TranslationHelper
    include ApplicationHelper
    include ActivitiesHelper
    include RailsIcons::Helpers::IconHelper
  end
end

# Support dynamic sidebar title with the :basket_price_extra_title name
module ActiveAdmin
  module Filters
    module ResourceExtension
      def filters_sidebar_section
        name = :filters
        ActiveAdmin::SidebarSection.new name, only: :index, if: -> { active_admin_config.filters.any? } do
          h3 I18n.t("active_admin.shared.sidebar_section.#{name}", default: name.to_s.titlecase), class: "filters-form-title"
          active_admin_filters_form_for assigns[:search], active_admin_config.filters,
            data: {
              controller: "filters",
              action: "change->filters#submit"
            }
        end
      end
    end
  end
end

module ActiveAdmin
  class DSL
    def sidebar_handbook_link(page, only: :index)
      section = ActiveAdmin::SidebarSection.new(:handbook, only: only) do
        div class: "flex justify-center" do
          a href: "/handbook/#{page}", class: "action-item-button small light" do
            span do
              icon "book-open", class: "w-5 h-5 me-2"
            end
            span do
              t("active_admin.site_footer.handbook")
            end
          end
        end
      end
      config.sidebar_sections << section
    end

    def sidebar_shop_admin_only_warning
      section = ActiveAdmin::SidebarSection.new(
        :shop_admin_only,
        if: -> { Current.acp.shop_admin_only },
        only: :index
      ) do
        para class: "p-2 rounded text-sm text-red-800 dark:text-red-100 bg-red-100 dark:bg-red-800" do
          t("active_admin.shared.sidebar_section.shop_admin_only_text_html")
        end
        if authorized?(:read, Current.acp)
          div class: "text-center text-sm mt-3" do
            a(href: "/settings#shop") { t("active_admin.shared.sidebar_section.edit_settings") }
          end
        end
      end
      config.sidebar_sections << section
    end
  end
end

# Allow to add table data attributes
module ActiveAdmin
  module Views
    class IndexAsTable < ActiveAdmin::Component
      def build(page_presenter, collection)
        add_class "index-as-table"
        table_options = {
          id: "index_table_#{active_admin_config.resource_name.plural}",
          sortable: true,
          i18n: active_admin_config.resource_class,
          paginator: page_presenter[:paginator] != false,
          row_class: page_presenter[:row_class]
        }

        # Support row_data and tbody extra options
        table_options[:row_data] = page_presenter[:row_data]
        table_options[:tbody] = page_presenter[:tbody]

        if page_presenter.block
          insert_tag(IndexTableFor, collection, table_options) do |t|
            instance_exec(t, &page_presenter.block)
          end
        else
          render "index_as_table_default", table_options: table_options
        end
      end
    end

    class TableFor < Arbre::HTML::Table
      def build(obj, *attrs)
        options = attrs.extract_options!
        @sortable = options.delete(:sortable)
        @collection = obj.respond_to?(:each) && !obj.is_a?(Hash) ? obj : [ obj ]
        @resource_class = options.delete(:i18n)
        @resource_class ||= @collection.klass if @collection.respond_to? :klass

        @columns = []
        @row_class = options.delete(:row_class)

        # Handle row_data and tbody extra options
        @tbody_options = options.delete(:tbody)
        @row_data = options.delete(:row_data)

        build_table
        super(options)
        add_class "data-table"
        columns(*attrs)
      end

      protected

      def build_table_body
        # Add tbody tag with data attributes
        @tbody = tbody @tbody_options do
          # Build enough rows for our collection
          @collection.each do |elem|
            # Add tr row data attributes
            data_attrs = @row_data ? @row_data.call(elem) : {}
            tr({ id: dom_id_for(elem), class: @row_class&.call(elem) }.merge(data_attrs))
          end
        end
      end
    end
  end
end

require "active_admin/filter_saver"
ActiveAdmin.before_load do |app|
  ActiveAdmin::BaseController.send :include, ActiveAdmin::FilterSaver
end

ActiveAdmin.after_load do |app|
  module ActiveAdmin
    module ViewHelpers
      module AutoLinkHelper
        def auto_link(resource, content = display_name(resource))
          kept = !resource.respond_to?(:kept?) || resource.kept?
          if kept && url = auto_url_for(resource)
            link_to content, url
          else
            content
          end
        end
      end
    end
  end
end
