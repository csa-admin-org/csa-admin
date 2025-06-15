# frozen_string_literal: true

ActiveAdmin.register_page "Handbook" do
  menu false

  content title: proc { t("active_admin.site_footer.handbook") } do
    div class: "markdown md:pr-4 content-page", data: { turbo: false } do
      handbook = Handbook.new(params[:id], binding)
      handbook.body
    end
  end

  sidebar :pages, only: :index do
    side_panel t(".pages") do
      ul class: "space-y-2 text-base" do
        Handbook.all(binding).each do |handbook|
          li class: (handbook.name == params[:id] ? "" : "") do
            if handbook.name == params[:id]
              div class: "font-bold flex items-center justify-start" do
                div { icon "chevron-down", class: "size-4 me-1" }
                span handbook.title
              end
              ol class: "mt-2 mb-6 ml-5 list-inside list-none space-y-1" do
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
                div class: "flex items-center justify-start" do
                  div { icon "chevron-right", class: "size-4 me-1" }
                  span handbook.title
                end
              end
            end
          end
        end
      end
    end
  end

  sidebar :help, if: -> { params[:id] } do
    side_panel t(".help") do
      para t("active_admin.page.index.handbook_questions_html")
    end
  end

  config.breadcrumb = false

  controller do
    before_action do
      redirect_to handbook_page_path(:getting_started) unless params[:id]
    end
  end
end
