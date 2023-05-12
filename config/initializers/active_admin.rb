require 'sane_patch'

ActiveAdmin.setup do |config|
  # == Site Title
  #
  # Set the title that is displayed on the main layout
  # for each of the active admin pages.
  #
  config.site_title = ->(view) { Current.acp.name }

  # Set the link url for the title. For example, to take
  # users to your main site. Defaults to no link.
  #
  # config.site_title_link = "/"

  # Set an optional image to be displayed for the header
  # instead of a string (overrides :site_title)
  #
  # Note: Aim for an image that's 21px high so it fits in the header.
  #
  # config.site_title_image = "logo.png"

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
  config.cancan_ability_class = 'Ability'

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

  # This setting changes the http method used when rendering the
  # link. For example :get, :delete, :put, etc..
  #
  # Default:
  config.logout_link_method = :delete

  # == Root
  #
  # Set the action to call for the root path. You can set different
  # roots for each namespace.
  #
  # Default:
  config.root_to = 'dashboard#index'

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

  # == Setting a Favicon
  #
  # config.favicon = '/assets/favicon.ico'

  # == Meta Tags
  #
  # Add additional meta tags to the head element of active admin pages.
  #
  # Add tags to all pages logged in users see:
  #   config.meta_tags = { author: 'My Company' }

  # By default, sign up/sign in/recover password pages are excluded
  # from showing up in search engine results by adding a robots meta
  # tag. You can reset the hash of meta tags included in logged out
  # pages:
  #   config.meta_tags_for_logged_out_pages = {}

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

  # == Register Stylesheets & Javascripts
  #
  # We recommend using the built in Active Admin layout and loading
  # up your own stylesheets / javascripts to customize the look
  # and feel.
  #
  # To load a stylesheet:
  #   config.register_stylesheet 'my_stylesheet.css'
  #
  # You can provide an options hash for more control, which is passed along to stylesheet_link_tag():
  #   config.register_stylesheet 'my_print_stylesheet.css', media: :print
  #
  # To load a javascript file:
  #   config.register_javascript 'my_javascript.js'

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
      menu.add label: -> { I18n.t('active_admin.menu.shop') }, priority: 6, id: :shop
      menu.add label: :activities_human_name, priority: 7
      menu.add label: -> { I18n.t('active_admin.menu.group_buying') }, priority: 8, id: :group_buying
      menu.add label: -> { I18n.t('active_admin.menu.billing') }, priority: 9, id: :billing
      menu.add label: -> { I18n.t('active_admin.menu.other') }, priority: 10, id: :other, html_options: { data: { controller: 'menu-sorting' } }
    end

    admin.build_menu :utility_navigation do |menu|
      admin.add_current_user_to_menu menu, 1
      admin.add_updates_notice_to_menu menu, 2
      admin.add_logout_button_to_menu menu, 3
    end
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
  config.download_links = [:csv]
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

  # == Head
  #
  # You can add your own content to the site head like analytics. Make sure
  # you only pass content you trust.
  #
  # config.head = ''.html_safe

  # == Footer
  #
  # By default, the footer shows the current Active Admin version. You can
  # override the content of the footer here.
  #
  config.footer = ->(footer) { render(partial: 'layouts/footer') }

  # == Sorting
  #
  # By default ActiveAdmin::OrderClause is used for sorting logic
  # You can inherit it with own class and inject it for all resources
  #
  # config.order_clause = MyOrderClause

  # == Webpacker
  #
  # By default, Active Admin uses Sprocket's asset pipeline.
  # You can switch to using Webpacker here.
  #
  config.use_webpacker = false
end

Rails.application.reloader.to_prepare do
  class ActiveAdmin::ResourceDSL
    include ActionView::Helpers::TranslationHelper
    include ApplicationHelper
    include ActivitiesHelper
  end
end

# Inject admin importmap tag to admin header
module ActiveAdmin
  module Views
    module Pages
      class Base < Arbre::HTML::Document
        private
        def build_active_admin_head
          within head do
            html_title [title, helpers.active_admin_namespace.site_title(self)].compact.join(" | ")

            text_node(active_admin_namespace.head)

            active_admin_namespace.meta_tags.each do |name, content|
              text_node(meta(name: name, content: content))
            end

            active_admin_application.stylesheets.each do |style, options|
              stylesheet_tag = active_admin_namespace.use_webpacker ? stylesheet_pack_tag(style, **options) : stylesheet_link_tag(style, **options)
              text_node(stylesheet_tag.html_safe) if stylesheet_tag
            end

            active_admin_application.javascripts.each do |path|
              javascript_tag = active_admin_namespace.use_webpacker ? javascript_pack_tag(path) : javascript_include_tag(path)
              text_node(javascript_tag)
            end

            # Inject Importmap
            text_node(javascript_importmap_tags 'admin')

            if active_admin_namespace.favicon
              text_node(favicon_link_tag(active_admin_namespace.favicon))
            end

            text_node csrf_meta_tag
          end
        end
      end
    end
  end
end

# Imported from https://github.com/formaweb/formadmin
module ActiveAdmin
  responsive_viewport = { viewport: 'width=device-width, initial-scale=1' }

  ActiveAdmin.application.meta_tags.merge! responsive_viewport
  ActiveAdmin.application.meta_tags_for_logged_out_pages.merge! responsive_viewport

  module Views
    class Header < Component
      alias_method :_build, :build

      def build namespace, menu
        _build namespace, menu
        build_responsive_menu
      end

      def build_responsive_menu
        button '<i></i>'.html_safe, type: 'button', class: 'menu-button', onclick: 'document.body.classList.toggle("opened-menu")'
      end
    end
  end
end

# Overwrite logout link with image
module ActiveAdmin
  class Namespace
    def add_updates_notice_to_menu(menu, priority = 10, html_options = {})
      menu.add \
        id: 'updates', priority: priority, html_options: html_options,
        label: -> {
          content_tag(:span) {
            inline_svg_tag('admin/gift.svg', size: '20') +
            content_tag(:span, '', class: 'badge')
          }
        },
        url: -> { updates_path },
        if: -> { Update.unread_count(current_active_admin_user).positive? }
    end

    def add_logout_button_to_menu(menu, priority = 20, html_options = {})
      if logout_link_path
        html_options = html_options.reverse_merge(method: logout_link_method || :get)
        menu.add \
          id: 'logout', priority: priority, html_options: html_options,
          label: -> { inline_svg_tag('admin/sign-out.svg', size: '20') },
          url: -> { render_or_call_method_or_proc_on self, active_admin_namespace.logout_link_path },
          if: :current_active_admin_user?
      end
    end
  end
end

module ActiveAdmin
  module Filters
    module ResourceExtension
      def filters_sidebar_section
        ActiveAdmin::SidebarSection.new :filters, only: :index, if: -> { active_admin_config.filters.any? } do
          active_admin_filters_form_for assigns[:search], active_admin_config.filters,
            data: {
              controller: 'filters',
              action: 'change->filters#submit'
            }
        end
      end
    end
  end

  module Inputs
    module Filters
      class DateRangeInput < ::Formtastic::Inputs::StringInput
        def input_html_options
          {
            size: 12,
            type: 'date'
           }.merge(options[:input_html] || {})
        end
      end
    end
  end
end

# Support dynamic sidebar title with the :basket_price_extra_title name
module ActiveAdmin
  class SidebarSection
    def title
      case name
      when 'basket_price_extra_title'
        Current.acp.basket_price_extra_title
      else
        I18n.t("active_admin.sidebars.#{name}", default: name.titleize)
      end
    end
  end
end

module ActiveAdmin
  class DSL
    def sidebar_handbook_link(page, only: :index)
      section = ActiveAdmin::SidebarSection.new(:handbook, only: only) do
        a href: "/handbook/#{page}" do
          span inline_svg_tag('admin/book-open.svg', size: '20')
          span t('layouts.footer.handbook')
        end
      end
      config.sidebar_sections << section
    end

    def sidebar_shop_admin_only_warning
      section = ActiveAdmin::SidebarSection.new(
        :shop_admin_only,
        if: -> { Current.acp.shop_admin_only },
        only: :index,
        class: 'warning'
      ) do
        div class: 'content' do
          span t('active_admin.sidebars.shop_admin_only_text_html')
          if authorized?(:read, Current.acp)
            para class: 'text-center' do
              a(href: '/settings#shop') { t('active_admin.sidebars.edit_settings') }
            end
          end
        end
      end
      config.sidebar_sections << section
    end

    def sidebar_group_buying_deprecation_warning
      section = ActiveAdmin::SidebarSection.new(
        :deprecation_warning,
        only: :index,
        class: 'warning'
      ) do
        div class: 'content' do
          span t('active_admin.sidebars.deprecation_warning_group_buying_text_html')
        end
      end
      config.sidebar_sections << section
    end
  end
end

require 'active_admin/filter_saver'
ActiveAdmin.before_load do |app|
  ActiveAdmin::BaseController.send :include, ActiveAdmin::FilterSaver
end

# https://github.com/activeadmin/activeadmin/issues/5712#issuecomment-508184641
ActiveAdmin.after_load do |app|
  app.namespaces.each do |namespace|
    namespace.fetch_menu(ActiveAdmin::DEFAULT_MENU)
  end
end
