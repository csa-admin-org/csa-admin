# frozen_string_literal: true

module ApplicationHelper
  include SmartRefererHelper

  MAIL_PREVIEW_HEIGHT_MESSAGE = "csa-admin:mail-preview-height"
  MAIL_PREVIEW_MEASURE_MESSAGE = "csa-admin:mail-preview-measure"
  MAIL_PREVIEW_HEIGHT_SCRIPT = <<~HTML.freeze
    <script>
    (function () {
      function post() {
        var height = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight);
        parent.postMessage({ type: #{MAIL_PREVIEW_HEIGHT_MESSAGE.to_json}, height: height }, "*");
      }
      window.addEventListener("message", function (event) {
        if (event.data && event.data.type === #{MAIL_PREVIEW_MEASURE_MESSAGE.to_json}) post();
      });
      window.addEventListener("load", post);
      window.addEventListener("resize", post);
      if (document.fonts && document.fonts.ready) document.fonts.ready.then(post);
      new ResizeObserver(post).observe(document.documentElement);
      post();
    })();
    </script>
  HTML

  # Lexxy hardcodes English chrome. Map those strings to the current locale.
  LEXXY_LABELS = {
    "Add images and video" => "lexxy.ui.add_image",
    "Bold" => "lexxy.ui.bold",
    "Italic" => "lexxy.ui.italic",
    "Strikethrough" => "lexxy.ui.strikethrough",
    "Text formatting" => "lexxy.ui.text_formatting",
    "Paragraph" => "lexxy.ui.paragraph",
    "Normal" => "lexxy.ui.normal",
    "Clear formatting" => "lexxy.ui.clear_formatting",
    "Color highlight" => "lexxy.ui.color_highlight",
    "Remove all coloring" => "lexxy.ui.remove_coloring",
    "Link" => "lexxy.ui.link",
    "Unlink" => "lexxy.ui.unlink",
    "Enter a URL…" => "lexxy.ui.enter_url",
    "Quote" => "lexxy.ui.quote",
    "Code" => "lexxy.ui.code",
    "Bullet list" => "lexxy.ui.bullet_list",
    "Numbered list" => "lexxy.ui.numbered_list",
    "Insert a table" => "lexxy.ui.insert_table",
    "Insert a divider" => "lexxy.ui.insert_divider",
    "Undo" => "lexxy.ui.undo",
    "Redo" => "lexxy.ui.redo",
    "More options" => "lexxy.ui.more_options",
    "Large Heading" => "lexxy.ui.large_heading",
    "Medium Heading" => "lexxy.ui.medium_heading",
    "Small Heading" => "lexxy.ui.small_heading",
    "Describe the image for people who can't see it:" => "lexxy.ui.alt_dialog_title",
    "Keep it short, but enough to convey the context…" => "lexxy.ui.alt_placeholder",
    "Description" => "lexxy.ui.description",
    "Alternative text" => "lexxy.ui.alternative_text",
    "Cancel" => "lexxy.ui.cancel",
    "Save" => "lexxy.ui.save",
    "Remove" => "lexxy.ui.remove",
    "Add caption..." => "lexxy.ui.add_caption",
    "Image caption" => "lexxy.ui.image_caption",
    "Delete this table?" => "lexxy.ui.delete_table",
    "row options" => "lexxy.ui.row_options",
    "column options" => "lexxy.ui.column_options",
    "Add row before" => "lexxy.ui.add_row_before",
    "Add row after" => "lexxy.ui.add_row_after",
    "Toggle row style" => "lexxy.ui.toggle_row_style",
    "Remove row" => "lexxy.ui.remove_row",
    "Add column before" => "lexxy.ui.add_column_before",
    "Add column after" => "lexxy.ui.add_column_after",
    "Toggle column style" => "lexxy.ui.toggle_column_style",
    "Remove column" => "lexxy.ui.remove_column",
    "__row_one" => "lexxy.ui.row_one",
    "__row_other" => "lexxy.ui.row_other",
    "__column_one" => "lexxy.ui.column_one",
    "__column_other" => "lexxy.ui.column_other"
  }.freeze

  def lexxy_labels_json
    LEXXY_LABELS.transform_values { |key| t(key) }.to_json
  end

  def mail_preview_iframe_sandbox
    "allow-scripts allow-popups allow-popups-to-escape-sandbox"
  end

  # Delivery names in page titles are HTML. Strip tags before joining, or
  # the document title escapes the markup and the tab shows it as text.
  def plain_document_title(separator: "-")
    title = @page_title
    title = page_title if title.blank? && respond_to?(:page_title)
    safe_join([ strip_tags(title.to_s), site_title ], " #{separator} ")
  end

  def mail_preview_srcdoc(html)
    html = html.to_s
    return html if html.blank?

    if html.match?(%r{</body>}i)
      html.sub(%r{</body>}i, "#{MAIL_PREVIEW_HEIGHT_SCRIPT}</body>")
    else
      "<!DOCTYPE html><html><body>#{html}#{MAIL_PREVIEW_HEIGHT_SCRIPT}</body></html>"
    end
  end

  def mail_preview_iframe(srcdoc, **options)
    data = { iframe_target: "iframe" }.merge(options.delete(:data) || {})
    tag.iframe(
      srcdoc: mail_preview_srcdoc(srcdoc),
      sandbox: mail_preview_iframe_sandbox,
      class: "mail_preview",
      scrolling: "no",
      data: data,
      **options)
  end

  def spaced(string, size: 3)
    string = string.to_s
    (size - string.length).times do
      string = "&emsp;#{string}"
    end
    string.html_safe
  end

  def text_format(text)
    simple_format(text) if text.present?
  end

  def csa_admin_website_url
    path =
      case I18n.locale
      when :fr, :it then "/acp"
      when :de then "/solawi"
      end
    "https://csa-admin.org#{path}"
  end

  # Ultra-admin jump to the Mission Control tenant launcher (cross-host).
  def mc_launcher_url
    if Rails.env.development? && ENV["DEV_ORIGIN"] == "localhost"
      host =
        if respond_to?(:request) && Tenant::Middleware::DEV_LAUNCHER_HOSTS.include?(request.host)
          request.host
        else
          "localhost"
        end
      "http://#{host}:#{ENV.fetch("PORT", "3000")}/"
    else
      domain = Rails.app.creds.option(:app_domain).presence ||
        (Rails.env.production? ? "csa-admin.org" : "csa-admin.test")
      "https://mc.#{domain}/"
    end
  end

  def display_emails_with_link(arbre, emails)
    return unless emails.present?

    arbre.ul class: "cluster is-snug" do
      Array(emails).map do |email|
        arbre.li class: "cluster is-snug" do
          display_email_with_link(arbre, email)
        end
      end
    end
  end

  def display_member_emails_with_link(arbre, emails)
    return unless emails.present?

    emails = Array(emails)
    unsubscriptions = EmailSuppression.active.manual.where(email: emails).index_by(&:email)

    arbre.ul class: "cluster is-snug" do
      emails.each do |email|
        arbre.li class: "cluster is-snug" do
          display_email_with_link(arbre, email)
          if (suppression = unsubscriptions[email])
            arbre.a href: handbook_page_path("newsletters", anchor: "subscribe"),
              title: I18n.t("active_admin.site_footer.handbook") do
              arbre.status_tag :manual_suppression,
                label: t("active_admin.resource.show.email_unsubscribed_since",
                  date: l(suppression.created_at.to_date))
            end
          end
        end
      end
    end
  end

  def display_name_with_public_name(object)
    txt = object.display_name
    if object.public_name != txt
      txt += content_tag(:span, object.public_name, class: "is-block text-sm is-muted")
    end
    txt.html_safe
  end

  def display_email_with_link(arbre, email)
    suppressions =
      EmailSuppression
        .visible
        .where(email: email)
    if suppressions.any?
      arbre.span class: "cluster is-snug" do
        arbre.s email
        suppressions.each do |suppression|
          arbre.status_tag suppression.reason.underscore
          if suppression.unsuppressable?
            arbre.span { reactivate_email_suppression_button(suppression, btn_class: "btn btn-xs") }
          end
        end
      end
    else
      arbre.text_node mail_to(email)
    end
  end

  def display_phones_with_link(arbre, phones)
    return unless phones.present?

    arbre.ul do
      Array(phones).map do |phone|
        arbre.li phone_link(phone)
      end
    end
  end

  def display_attachment(attachment)
    link_to(
      "#{attachment.filename} (#{number_to_human_size(attachment.byte_size)})",
      rails_blob_path(attachment, disposition: "attachment"))
  end

  def phone_link(phone)
    phone_to(
      phone.phony_formatted(spaces: "", format: :international),
      display_phone(phone))
  end

  def display_phone(phone)
    format =
      if PhonyRails.country_from_number(phone) == Current.org.country_code
        :national
      else
        :international
      end
    phone.phony_formatted(format: format)
  end

  def display_price_description(price, description)
    txt = ""
    unless price.zero?
      txt += content_tag(:span, description, class: "text-sm is-muted")
      txt += " "
    end
    txt += content_tag(:span, cur(price, unit: false))
    txt.html_safe
  end

  def any_basket_complements?
    BasketComplement.kept.any?
  end

  def fiscal_years_collection
    Current.org.fiscal_years.map { |fy|
      [ fy.to_s, fy.year ]
    }.reverse
  end

  def renewal_states_collection
    Membership::Renewal::STATES.map { |state|
      [ I18n.t("active_admin.status_tag.#{state}").capitalize, state ]
    }
  end

  def display_objects(objects, limit: 5)
    return "–" if objects.empty?

    links = objects.first(limit).map { |o| auto_link(o) }
    if objects.size > limit
      links.join(", ").html_safe + ", ..."
    else
      links.to_sentence.html_safe
    end
  end

  def wdays_collection(novalue = nil)
    col = Array(0..6).rotate.map { |d| [ I18n.t("date.day_names")[d].capitalize, d ] }
    col = [ [ novalue, nil ] ] + col if novalue
    col
  end

  def months_collection(fiscal_year_order: false)
    months = Array(1..12)
    if fiscal_year_order
      months = months.rotate(Current.fiscal_year.range.min.month - 1)
    end
    months.map { |d|
      [ I18n.t("date.month_names")[d].capitalize, d ]
    }
  end

  def theme_icon_select_options
    HasTheme::THEMES.map { |theme|
      {
        value: theme,
        label: t("themes.#{theme}"),
        icon_name: HasTheme::THEME_ICONS.fetch(theme)
      }
    }
  end

  def handbook_icon_link(*args)
    link_to handbook_page_path(*args), title: I18n.t("active_admin.site_footer.handbook") do
      icon "book-open", class: "icon-5"
    end
  end

  def newsletter_publication_panel_action(publication)
    feed_url = publication.template.feed_url
    return if feed_url.blank?

    label = t("active_admin.resources.newsletter_template.feed_url")
    link_to(
      feed_url,
      title: label,
      aria: { label: label },
      target: "_blank",
      rel: "noopener") do
      icon "external-link", class: "icon-5"
    end
  end
end
