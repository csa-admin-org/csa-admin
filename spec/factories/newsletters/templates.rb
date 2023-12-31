FactoryBot.define do
  factory :newsletter_template, class: Newsletter::Template do
    title { "newsletter" }
    content { <<~LIQUID }
      Salut {{ member.name }},

      {% content id: 'main', title: "Content Title" %}
        Example Text {{ member.name }}
      {% endcontent %}
    LIQUID
  end
end
