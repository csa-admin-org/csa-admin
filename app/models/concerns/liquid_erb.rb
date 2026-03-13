# frozen_string_literal: true

# Renders `.liquid.erb` template files through ERB, resolving `<%= t('.key') %>`
# calls into translated text while leaving Liquid syntax (`{% %}`, `{{ }}`)
# untouched for subsequent Liquid parsing.
#
# The `t()` helper infers its I18n scope from the directory and file name:
#   - `app/views/mail_templates/basket_first.liquid.erb`
#     → scope: `mail_template_defaults.basket_first`
#   - `app/views/admin_mailer/invitation_email.liquid.erb`
#     → scope: `admin_mailer.invitation_email`
#
# Usage:
#   LiquidErb.render("mail_templates/basket_first", locale: :en)
#   # => "<p>Today is the delivery day of your first basket of the year.</p>\n..."
#
module LiquidErb
  VIEWS_DIR = Rails.root.join("app/views")

  # Maps view directory names to I18n scope prefixes.
  # Directories not listed here use their name as-is (e.g. "admin_mailer").
  SCOPE_MAP = {
    "mail_templates" => "mail_template_defaults",
    "newsletter_templates" => "newsletter_template_defaults"
  }.freeze

  # Renders a `.liquid.erb` template for the given locale.
  #
  # @param template_path [String] relative path under app/views/ without extension
  #   e.g. "mail_templates/basket_first" or "admin_mailer/invitation_email"
  # @param locale [String, Symbol] the locale to render with
  # @return [String] the rendered Liquid content (ERB resolved, Liquid intact)
  def self.render(template_path, locale:)
    file = VIEWS_DIR.join("#{template_path}.liquid.erb")
    raise ArgumentError, "Template not found: #{file}" unless file.exist?

    erb_source = File.read(file)
    dir, name = template_path.split("/", 2)
    scope_prefix = SCOPE_MAP.fetch(dir, dir)
    i18n_scope = "#{scope_prefix}.#{name}"
    context = RenderContext.new(i18n_scope)

    I18n.with_locale(locale) do
      ERB.new(erb_source).result(context.get_binding)
    end
  end

  # Minimal rendering context that provides a `t()` helper for ERB templates.
  # Keeps the binding clean — only `t()` is available, no controller/view helpers.
  class RenderContext
    def initialize(i18n_scope)
      @i18n_scope = i18n_scope
    end

    def get_binding
      binding
    end

    private

    # Translates a key, using the template's I18n scope for relative keys.
    #
    #   t('.first_basket_paragraph')
    #   # with @i18n_scope = "mail_template_defaults.basket_first"
    #   # → I18n.t("mail_template_defaults.basket_first.first_basket_paragraph")
    #
    # Absolute keys (without leading dot) are passed through directly.
    def t(key, **options)
      if key.start_with?(".")
        I18n.t("#{@i18n_scope}#{key}", **options)
      else
        I18n.t(key, **options)
      end
    end
  end
end
