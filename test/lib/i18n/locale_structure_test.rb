# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "locales"
require "tmpdir"

class LocaleStructureTest < ActiveSupport::TestCase
  BASKET_SCOPES = %w[basket bag share package cone crate].freeze
  ACTIVITY_SCOPES = %w[hour_work halfday_work day_work basket_preparation].freeze
  LOCALES = %i[en fr de it nl].freeze


  test "requires matching interpolation tokens" do
    violations = structure_violations(
      "_" => {
        "messages" => {
          "greeting" => {
            "_en" => "Order %{number}: %{url}",
            "_fr" => "Commande %{number}: %{url}",
            "_de" => "Bestellung %{number}: %{url}",
            "_it" => "Ordine %{numero}: %{url}",
            "_nl" => "Bestelling %{number}: %{url}"
          }
        }
      }
    )

    assert_includes violations, "messages.greeting._it: interpolation tokens %{numero}, %{url} do not match English %{number}, %{url}"
  end

  test "requires matching Liquid output tokens" do
    violations = structure_violations(
      "_" => {
        "messages" => {
          "handbook_link" => {
            "_en" => "Read {{ handbook_url }}",
            "_fr" => "Lire {{ handbook_url }}",
            "_de" => "{{ handbook_url }} lesen",
            "_it" => "Leggere {{ manual_url }}",
            "_nl" => "Lees {{ handbook_url }}"
          }
        }
      }
    )

    assert_includes violations, "messages.handbook_link._it: Liquid output tokens {{ manual_url }} do not match English {{ handbook_url }}"
  end

  test "allows an omitted base only for a complete scoped matrix" do
    complete_matrix = BASKET_SCOPES.to_h do |scope|
      [ "title/#{scope}", localized_values(scope) ]
    end

    assert_empty structure_violations("_" => { "labels" => complete_matrix }).grep(/missing basket scopes/)

    incomplete_matrix = { "title/bag" => localized_values("bag") }
    violations = structure_violations("_" => { "labels" => incomplete_matrix })

    assert_includes violations, "labels.title: missing basket scopes: basket, share, package, cone, crate (add an unscoped fallback or all basket scopes)"

    with_fallback = incomplete_matrix.merge("title" => localized_values("default"))
    assert_empty structure_violations("_" => { "labels" => with_fallback }).grep(/missing basket scopes/)
  end

  test "checks scoped matrices above plural branches" do
    translations = {
      "_" => {
        "messages" => {
          "notice/bag" => {
            "one" => localized_values("One bag"),
            "other" => localized_values("Many bags")
          }
        }
      }
    }

    violations = structure_violations(translations)

    assert_includes violations, "messages.notice.one: missing basket scopes: basket, share, package, cone, crate (add an unscoped fallback or all basket scopes)"
    assert_includes violations, "messages.notice.other: missing basket scopes: basket, share, package, cone, crate (add an unscoped fallback or all basket scopes)"
  end

  test "rejects scopes on unreachable nested keys" do
    nested_matrix = BASKET_SCOPES.to_h do |scope|
      [ "title/#{scope}", { "short" => localized_values(scope) } ]
    end

    violations = structure_violations("_" => { "labels" => nested_matrix })

    assert_includes violations, "labels.title/bag.short: scope must be on the translation key or directly above a plural branch"
  end

  test "rejects invalid line breaks" do
    violations = structure_violations(
      "_" => {
        "messages" => {
          "hint_html" => localized_values("First line<br>Second line").merge("_fr" => "Première ligne</br>Deuxième ligne")
        }
      }
    )

    assert_includes violations, "messages.hint_html._fr: invalid </br>; use <br> or <br/>"
  end

  test "rejects typographic double quotes" do
    violations = structure_violations(
      "_" => { "messages" => { "quoted" => localized_values("Use «straight quotes»") } }
    )

    assert_includes violations, "messages.quoted._fr: use straight double quotes, not typographic quotes"
  end

  test "enforces scoped html, Swiss German, and US English structure" do
    violations = structure_violations(
      "_" => {
        "messages" => {
          "notice_html/bag" => localized_values("Notice"),
          "german" => localized_values("Text").merge("_de" => "Straße"),
          "cancelled" => localized_values("Text").merge("_en" => "Cancelled"),
          "cancelation" => localized_values("Text").merge("_en" => "Cancelation")
        }
      }
    )

    assert_includes violations, "messages.notice_html/bag: scope must precede _html (use notice/bag_html)"

    plural_html_violations = structure_violations(
      "_" => { "messages" => { "notice_html/bag" => { "one" => localized_values("Notice") } } }
    )
    assert_includes plural_html_violations, "messages.notice_html/bag.one: scope must precede _html (use notice/bag_html)"
    assert_includes violations, "messages.german._de: Swiss German uses ss, not ß"
    assert_includes violations, "messages.cancelled._en: use canceled, not cancelled"
    assert_includes violations, "messages.cancelation._en: use cancellation, not cancelation"
  end

  test "rejects duplicate locale leaves within one file" do
    Dir.mktmpdir do |root|
      file = Pathname.new(root).join("duplicate.yml")
      File.write(file, "_:\n  greeting:\n    _en: First\n    _en: Second\n")

      violations = Locales::Structure.duplicate_leaf_violations([ file.to_s ])

      assert_equal 1, violations.size
      assert_includes violations.first, "duplicate YAML key greeting._en"
      assert_includes violations.first, "first defined at line 3"
    end
  end

  test "rejects duplicate locale leaves across files" do
    Dir.mktmpdir do |root|
      locale_directory = Pathname.new(root).join("config/locales")
      FileUtils.mkdir_p(locale_directory)
      first = locale_directory.join("first.yml")
      second = locale_directory.join("second.yml")
      content = "_:\n  greeting:\n    _en: Hello\n"
      File.write(first, content)
      File.write(second, content)

      violations = Locales::Structure.duplicate_leaf_violations([ first.to_s, second.to_s ])

      assert_equal 1, violations.size
      assert_includes violations.first, "greeting._en: duplicate locale leaf"
      assert_includes violations.first, first.to_s
      assert_includes violations.first, second.to_s
    end
  end

  test "parses every Liquid ERB template in every locale" do
    errors = Dir[Rails.root.join("app/views/**/*.liquid.erb")].flat_map do |file|
      template_name = Pathname.new(file).relative_path_from(Rails.root.join("app/views")).to_s.delete_suffix(".liquid.erb")

      Organization.languages.filter_map do |locale|
        rendered = LiquidErb.render(template_name, locale: locale)
        template = Liquid::Template.parse(rendered, error_mode: :strict)
        "#{template_name} (#{locale}): #{template.errors.join(", ")}" if template.errors.any?
      rescue => error
        "#{template_name} (#{locale}): #{error.class}: #{error.message}"
      end
    end

    assert_empty errors, errors.join("\n")
  end

  test "rejects typographic double quotes in views" do
    Dir.mktmpdir do |root|
      view_directory = Pathname.new(root).join("app/views/handbook")
      FileUtils.mkdir_p(view_directory)
      file = view_directory.join("example.fr.md.erb")
      File.write(file, "Utilisez «Enregistrer».\n")

      violations = Locales::Structure.typographic_quote_violations(Locales::Structure.view_files(root: Pathname.new(root)))

      assert_equal [ "#{file}:1: use straight double quotes, not typographic quotes" ], violations
    end
  end

  test "rejects hardcoded copy in high-signal user-facing sinks" do
    checks = {
      "literal validation error" => [ Dir[Rails.root.join("app/models/**/*.rb")], /errors\.add\([^\n]*,\s*["'][A-Za-zÀ-ÿ]/ ],
      "literal JavaScript alert" => [ Dir[Rails.root.join("app/javascript/**/*.js")], /\balert\(\s*["'][A-Za-z]/ ],
      "literal ERB aria-label" => [ Dir[Rails.root.join("app/views/**/*.erb")], /aria-label=["'][A-Za-z]/ ],
      "literal Ruby aria label" => [ Dir[Rails.root.join("app/**/*.rb")], /aria:\s*\{\s*label:\s*["'][A-Za-z]/ ]
    }
    violations = checks.flat_map do |description, (files, pattern)|
      files.flat_map do |file|
        File.readlines(file).each_with_index.filter_map do |line, index|
          "#{file}:#{index + 1}: #{description}" if line.match?(pattern)
        end
      end
    end

    assert_empty violations, violations.join("\n")
  end

  test "loads yaml locale files" do
    Dir.mktmpdir do |root|
      locale_directory = Pathname.new(root).join("config/locales")
      FileUtils.mkdir_p(locale_directory)
      file = locale_directory.join("example.yaml")
      File.write(file, "_:\n  greeting:\n    _en: Hello\n")

      files = Locales::Structure.locale_files(root: Pathname.new(root))

      assert_equal [ file.to_s ], files
      assert_equal({ "_" => { "greeting" => { "_en" => "Hello" } } }, Locales::Structure.load_translations(files))
    end
  end

  private

  def structure_violations(translations)
    Locales::Structure.violations(
      translations,
      locales: LOCALES,
      basket_scopes: BASKET_SCOPES,
      activity_scopes: ACTIVITY_SCOPES
    )
  end

  def localized_values(value)
    LOCALES.index_with { value }
      .transform_keys { |locale| "_#{locale}" }
  end
end
