ActiveAdmin.register_page "Handbook" do
  menu false

  content title: proc { t("layouts.footer.handbook") } do
    columns do
      column do
        div class: "content" do
          handbook = Handbook.new(params[:id], binding)
          handbook.body
        end
      end
    end
  end

  sidebar :pages do
    ul class: "handbook-toc" do
      Handbook.all(binding).each do |handbook|
        li class: (handbook.name == params[:id] ? "active" : "") do
          if handbook.name == params[:id]
            span class: "active" do
              span inline_svg_tag("admin/chevron-down.svg", size: "12")
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
              span inline_svg_tag("admin/chevron-right.svg", size: "12")
              span handbook.title
            end
          end
        end
      end
    end
  end

  sidebar :help, if: -> { params[:id] } do
    div class: "content" do
      para t(".handbook_questions_html")
    end
  end

  config.breadcrumb = false

  controller do
    before_action do
      redirect_to handbook_page_path(:getting_started) unless params[:id]
    end
  end
end
