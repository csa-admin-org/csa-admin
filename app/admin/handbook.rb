ActiveAdmin.register_page 'Handbook' do
  menu false

  content title: I18n.t('layouts.footer.handbook') do
    if params[:id]
      columns do
        column do
          div class: 'content' do
            handbook = Handbook.new(params[:id],binding)
            handbook.body
          end
        end
      end
    else
      columns do
        column do
          div class: 'content' do
            h1 t('.handbook_intro_title')
            para t('.handbook_intro_html'), class: 'notice'
          end
        end
      end
    end
  end

  sidebar I18n.t('active_admin.page.index.pages') do
    ul class: 'handbook-toc' do
      li do
        if params[:id]
          a href: handbook_path do
            span t('.handbook_intro_title')
          end
        else
          span t('.handbook_intro_title'), class: 'active'
        end
      end
      Handbook.all(binding).each do |handbook|
        li class: (handbook.name == params[:id] ? 'active' : '') do
          if handbook.name == params[:id]
            span class: 'active' do
              span inline_svg_tag('admin/chevron-down.svg', size: '12')
              span handbook.title
            end
            ul do
              handbook.subtitles.each do |subtitle, id|
                li do
                  a href: handbook_page_path(handbook.name, anchor: id) do
                    span subtitle
                  end
                end
              end
            end
          else
            a href: handbook_page_path(handbook.name) do
              span inline_svg_tag('admin/chevron-right.svg', size: '12')
              span handbook.title
            end
          end
        end
      end
    end
  end

  sidebar I18n.t('active_admin.page.index.help'), if: -> { params[:id] } do
    div class: 'content' do
      para t('.handbook_questions_html')
    end
  end

  config.breadcrumb = false
end
