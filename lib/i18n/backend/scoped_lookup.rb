# frozen_string_literal: true

module I18n
  module Backend
    # Automatically resolves scoped translation key variants based on the
    # current organization's basket and activity i18n scopes.
    #
    # When an org has basket_i18n_scopes: {"fr" => "basket", "de" => "bag"},
    # a lookup for "activerecord.attributes.basket.basket_size" in :de will
    # first try "activerecord.attributes.basket.basket_size/bag" and fall back
    # to the unscoped key if the scoped variant doesn't exist.
    #
    # The basket scope is resolved per-locale from the JSON hash, falling back
    # to the org's default_locale scope when a language has no explicit scope.
    #
    # This works because scoped YAML keys use a `/scope` suffix convention
    # where the `/` is part of the key name (not a nesting separator):
    #
    #   basket_size:       "Grösse"       # unscoped fallback
    #   basket_size/bag:   "Grösse"       # bag scope variant
    #   basket_size/basket: "Korbgrösse"  # basket scope variant
    #
    # Prepend this module into the I18n backend to enable automatic resolution:
    #
    #   I18n::Backend::SideBySide.prepend(I18n::Backend::ScopedLookup)
    #
    module ScopedLookup
      protected

      def lookup(locale, key, scope = [], options = {})
        scopes = active_i18n_scopes(locale)
        return super unless scopes.any? && key

        scopes.each do |i18n_scope|
          scoped_key = append_scope_to_key(key, i18n_scope)
          result = super(locale, scoped_key, scope, options)
          return result unless result.nil?
        end

        super
      end

      private

      def active_i18n_scopes(locale = nil)
        if org = Current.org
          [ org.basket_i18n_scope_for(locale), org.activity_i18n_scope ].compact
        else
          []
        end
      rescue
        []
      end

      # Appends "/scope" to the last segment of the key, respecting the
      # `_html` suffix convention. When a key ends with `_html`, the scope
      # is inserted before the suffix so that Rails' HTML-safe handling
      # continues to work:
      #
      #   :basket_size              -> :"basket_size/bag"
      #   :description_html         -> :"description/bag_html"
      #   "a.b.warning_html"        -> "a.b.warning/bag_html"
      #   "a.b.basket_changed"      -> "a.b.basket_changed/bag"
      #
      def append_scope_to_key(key, scope)
        key_str = key.to_s
        last_dot = key_str.rindex(".")
        prefix = last_dot ? key_str[0..last_dot] : ""
        last_segment = last_dot ? key_str[(last_dot + 1)..] : key_str

        scoped_segment = if last_segment.end_with?("_html")
          "#{last_segment.delete_suffix("_html")}/#{scope}_html"
        else
          "#{last_segment}/#{scope}"
        end

        result = "#{prefix}#{scoped_segment}"
        key.is_a?(Symbol) ? result.to_sym : result
      end
    end
  end
end
