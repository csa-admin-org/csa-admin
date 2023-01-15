require 'rails_helper'

describe Newsletter::Template do
  let(:template) { create(:newsletter_template) }

  specify 'audit content changes' do
    session = create(:session, :admin)
    Current.session = session
    template = create(:newsletter_template, content: 'Salut {{ member.name }}')

    expect {
      template.update!(content: 'Hello {{ member.name }}')
    }.to change(Audit, :count).by(1)

    audit = template.audits.last
    expect(audit.session).to eq session
    expect(audit.audited_changes['contents'].last['fr']).to eq 'Hello {{ member.name }}'
  end

  specify 'validate unique content block ids' do
    template = build(:newsletter_template, content: <<~LIQUID)
      {% content id: 'main' %}{% endcontent %}
      {% content id: 'main' %}{% endcontent %}
    LIQUID

    expect(template).not_to have_valid(:content_fr)
  end

  specify 'validate same content block ids for all languages' do
    Current.acp.update! languages: %w[fr de]
    template = build(:newsletter_template,
      content_fr: <<~LIQUID,
        {% content id: 'first' %}{% endcontent %}
        {% content id: 'second' %}{% endcontent %}
      LIQUID
      content_de: <<~LIQUID)
        {% content id: 'first' %}{% endcontent %}
        {% content id: 'third' %}{% endcontent %}
      LIQUID

    expect(template).not_to have_valid(:content_de)
    expect(template).not_to have_valid(:content_fr)
  end

  specify 'validate liquid syntax' do
    template.content = 'Hello {% foo %}'
    expect(template).not_to have_valid(:content_fr)
  end

  specify 'validate content presence' do
    template.content = ''
    expect(template).not_to have_valid(:content_fr)
  end

  specify 'validate content HTML syntax' do
    template.content = '<p>Hello<//p>'
    expect(template).not_to have_valid(:content_fr)
  end

  specify 'list content blocks' do
    template.content = <<~LIQUID
      Salut {{ member.name }},

      {% content id: 'main', title: "Content Title" %}
      Example Text {{ member.name }}
        {{ member.email }}
      {% endcontent %}

      <p>bla bla</p>

      {% content id: 'second', title: "Second Title" %}
      {% endcontent %}

      <p>bla bla</p>

      {% content id: 'third' %}
      <p>Third Content</p>
      {% endcontent %}

      <p>bla bla</p>
    LIQUID


    expect(template.content_block_ids).to eq %w[main second third]
    content_blocks = template.content_blocks['fr']
    expect(content_blocks.map(&:title)).to eq [
      'Content Title',
      'Second Title',
      nil
    ]
    expect(content_blocks.map(&:raw_body)).to eq [
      "<div>Example Text {{ member.name }}\n  {{ member.email }}</div>",
      "<div></div>",
      "<div><p>Third Content</p></div>"
    ]
  end

  specify 'mailpreview' do
    template.content_fr = <<~LIQUID
      Salut {{ member.name }},

      {% content id: 'main', title: "Content Title" %}
      Example Text {{ member.name }}
      {% endcontent %}

      {% content id: 'second', title: "Second Title" %}
      {% endcontent %}

      {% content id: 'third' %}
      <p>Third Content</p>
      {% endcontent %}

      <p>bla bla</p>
    LIQUID
    template.liquid_data_preview_yamls = {
      'fr' => <<~YAML
        member:
          name: Bob Dae
        subject: Newsletter
      YAML
    }

    mail = template.mail_preview('fr')
    expect(mail).to include 'Salut Bob Dae,'
    expect(mail).to include 'Content Title</h2>'
    expect(mail).to include 'Example Text Bob Dae'
    expect(mail).not_to include 'Second Title/h2>'
    expect(mail).to include 'Third Content</p>'
    expect(mail).to include 'bla bla</p>'
  end
end
