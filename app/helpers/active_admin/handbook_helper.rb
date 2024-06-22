# frozen_string_literal: true

module ActiveAdmin::HandbookHelper
  def handbook_button(arbre, page, **options)
    arbre.para class: "mt-4 flex justify-center" do
      arbre.a href: handbook_page_path(page, **options), class: "action-item-button light small" do
        arbre.span icon("book-open", class: "h-5 w-5 me-1", title: I18n.t("active_admin.site_footer.handbook"))
        arbre.span t(".check_handbook")
      end.html_safe
    end
  end
end
