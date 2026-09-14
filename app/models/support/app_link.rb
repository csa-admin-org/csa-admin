# frozen_string_literal: true

module Support
  class AppLink
    SKIP_ANCESTORS = %w[pre code].freeze

    def self.rewrite(html)
      source = html.to_s
      return html if source.blank? || !source.match?(/https?:/i)

      fragment = Nokogiri::HTML::DocumentFragment.parse(source)
      flatten_rich_links!(fragment)
      fragment.css("a[href]").each { |node| rewrite_node(node) }
      collapse_host_only!(fragment)
      fragment.to_html.html_safe
    end

    def self.recognize(path)
      return if path.blank?

      load_admin_routes!
      host = Tenant.admin_host.presence || "admin.example.test"
      env = Rack::MockRequest.env_for("https://#{host}#{path}", "HTTP_HOST" => host)
      params = nil
      Rails.application.routes.router.recognize(ActionDispatch::Request.new(env)) { |_route, matched|
        params = matched
        break
      }
      params
    rescue ActionController::RoutingError
      nil
    end

    def initialize(href)
      @original = href.to_s.strip
      @uri = URI.parse(@original)
    end

    attr_reader :original

    def local?
      @uri.is_a?(URI::HTTP) && @uri.host.present? &&
        Tenant.find_by(host: @uri.host) == Tenant.current
    end

    def admin?
      PublicSuffix.parse(@uri.host).trd == "admin"
    rescue PublicSuffix::Error
      false
    end

    def local_href
      options = Tenant.local_url_options(@uri.host)
      URI::Generic.build(
        scheme: options[:protocol],
        host: options[:host],
        port: options[:port]&.to_i,
        path: @uri.path.presence || "/",
        query: @uri.query,
        fragment: @uri.fragment).to_s
    end

    def label
      return unless admin?

      params = self.class.recognize(@uri.path)
      return unless params

      case params[:controller]
      when "organizations" then settings_label(params)
      when "handbook" then handbook_label(params)
      when "dashboard" then I18n.t("active_admin.dashboard")
      when "updates" then I18n.t("active_admin.site_header.updates")
      when "analytics"
        Analytics::PAGES[params[:id]&.to_sym]&.title ||
          I18n.t("active_admin.site_header.analytics")
      when "sessions" then nil
      else resource_label(params)
      end
    end

    def self.load_admin_routes!
      resources = ActiveAdmin.application.namespaces[:root]&.resources
      return if resources&.any?

      Rails.application.reload_routes!
    end
    private_class_method :load_admin_routes!

    def self.settings
      @settings ||= Settings.new
    end

    class Settings
      include ActionView::Helpers::TranslationHelper
      include ActivitiesHelper
      include ActiveAdmin::OrganizationSettingsHelper
    end
    private_constant :Settings

    def self.resource_for(controller_path)
      load_admin_routes!
      resources = ActiveAdmin.application.namespaces[:root]&.resources
      return unless resources

      resources.grep(ActiveAdmin::Resource).find { |resource|
        resource.controller.controller_path == controller_path
      }
    end

    def self.url_like?(text, href)
      texts = [ text.to_s, CGI.unescape(text.to_s) ].map { |value| fold_url(value) }
      return true if texts.any?(&:blank?)

      hrefs = [ href, CGI.unescape(href.to_s) ].uniq.map { |value| fold_url(value) }
      texts.intersect?(hrefs)
    rescue ArgumentError
      false
    end

    def self.fold_url(value)
      value.to_s.gsub(/\s+/, "").delete_suffix("/")
    end
    private_class_method :fold_url

    def self.rewrite_node(node)
      return if node.ancestors.any? { |ancestor| SKIP_ANCESTORS.include?(ancestor.name) }

      link = new(node["href"])
      return unless link.local?

      original = link.original
      node["href"] = link.local_href
      node.remove_attribute("target")
      return unless link.admin? && link.label.present? && url_like?(node.text, original)

      node["class"] = [ node["class"], "btn support-app-link" ].compact.join(" ").squish
      node["title"] = original
      node.content = link.label
    rescue URI::InvalidURIError
      nil
    end
    private_class_method :rewrite_node

    def self.flatten_rich_links!(root)
      root.css(".apple-rich-link").each do |card|
        href = card["data-url"].presence || card.at("a[href]")&.[]("href")
        next if href.blank?

        link = Nokogiri::XML::Node.new("a", card.document)
        link["href"] = href
        link.content = href
        card.replace(link)
      end
    end
    private_class_method :flatten_rich_links!

    def self.collapse_host_only!(root)
      root.css("a.support-app-link").each do |button|
        link = previous_anchor(button)
        next unless link && host_only?(link) && same_path?(link["href"], button["href"])

        wrapper = link.parent
        link.remove
        if wrapper&.name == "p" && wrapper.text.strip.blank? && wrapper.element_children.empty?
          wrapper.remove
        end
      end
    end
    private_class_method :collapse_host_only!

    def self.previous_anchor(node)
      start = node.parent&.name == "p" && node.parent.css("a").size == 1 ? node.parent : node
      sibling = start.previous_sibling
      while sibling
        if sibling.element?
          return sibling if sibling.name == "a"
          found = sibling.at("a")
          return found if found
        end
        sibling = sibling.previous_sibling
      end
      nil
    end
    private_class_method :previous_anchor

    def self.host_only?(node)
      text = node.text.to_s.strip.delete_prefix("https://").delete_prefix("http://").delete_suffix("/")
      text.present? && text.exclude?("/") && text.exclude?(" ")
    end
    private_class_method :host_only?

    def self.same_path?(left, right)
      a = URI.parse(left.to_s)
      b = URI.parse(right.to_s)
      a.path == b.path && a.query == b.query && a.fragment == b.fragment
    rescue URI::InvalidURIError
      false
    end
    private_class_method :same_path?

    private

    def settings_label(params)
      page = I18n.t("active_admin.resources.organization.edit_model")
      key = params[:section].presence || @uri.fragment.presence
      title = setting_section_title(key)
      title.present? ? "#{page}: #{title}" : page
    end

    def setting_section_title(key)
      return if key.blank?

      section = self.class.settings.organization_setting_section(key)
      return unless section

      self.class.settings.organization_setting_section_title(section)
    end

    def handbook_label(params)
      page = I18n.t("active_admin.site_header.handbook")
      name = params[:id].to_s
      return page if name.blank?

      found = Handbook.headings_for(I18n.locale).find { |heading| heading[:name] == name }
      return page unless found

      parts = [ found[:title] ]
      if @uri.fragment.present?
        subtitle = found[:subtitles].find { |_text, anchor, _normalized| anchor == @uri.fragment }
        parts << subtitle[0] if subtitle
      end
      "#{page}: #{parts.join(" > ")}"
    end

    def resource_label(params)
      resource = self.class.resource_for(params[:controller])
      return unless resource

      name = resource.resource_class.model_name.human(count: 2)
      id = params[:id]
      if id.present? && params[:action] != "index"
        "#{name} ##{id}"
      else
        name
      end
    end
  end
end
