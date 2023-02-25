module ActiveAdmin::HandbookHelper
  def handbook_button(arbre, page, **options)
    arbre.para class: 'actions' do
      arbre.a href: handbook_page_path(page, **options), class: 'action' do
        arbre.span do
          arbre.span inline_svg_tag('admin/book-open.svg', size: '20', title: I18n.t('layouts.footer.handbook'))
          arbre.span t('.check_handbook')
        end
      end.html_safe
    end
  end
end
