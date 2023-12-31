require "rails_helper"

describe Newsletter::Template do
  let(:template) { create(:newsletter_template) }

  specify "audit content changes" do
    session = create(:session, :admin)
    Current.session = session
    template = create(:newsletter_template, content: "Salut {{ member.name }}")

    expect {
      template.update!(content: "Hello {{ member.name }}")
    }.to change(Audit, :count).by(1)

    audit = template.audits.last
    expect(audit.session).to eq session
    expect(audit.audited_changes["contents"].last["fr"]).to eq "Hello {{ member.name }}"
  end

  specify "validate unique content block ids" do
    template = build(:newsletter_template, content: <<~LIQUID)
      {% content id: 'main' %}{% endcontent %}
      {% content id: 'main' %}{% endcontent %}
    LIQUID

    expect(template).not_to have_valid(:content_fr)
  end

  specify "validate same content block ids for all languages" do
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

  specify "validate liquid syntax" do
    template.content = "Hello {% foo %}"
    expect(template).not_to have_valid(:content_fr)
  end

  specify "validate content presence" do
    template.content = ""
    expect(template).not_to have_valid(:content_fr)
  end

  specify "validate content HTML syntax" do
    template.content = "<p>Hello<//p>"
    expect(template).not_to have_valid(:content_fr)
  end

  specify "list content blocks" do
    template.content = <<~LIQUID
      Salut {{ member.name }},

      {% content id: 'main', title: "Content Title" %}
      Example Text {{ member.name }}
        {% if member.email %}
          Hello {{ member.email }}
        {% endif %}
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
    content_blocks = template.content_blocks["fr"]
    expect(content_blocks.map(&:title)).to eq [
      "Content Title",
      "Second Title",
      nil
    ]
    expect(content_blocks.map(&:raw_body)).to eq [
      "<div>Example Text {{ member.name }}\n  {% if member.email  %}\n  Hello {{ member.email }}\n{% endif %}</div>",
      "<div></div>",
      "<div><p>Third Content</p></div>"
    ]
  end

  specify "mailpreview" do
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
      "fr" => <<~YAML
        member:
          name: Bob Dae
        subject: Newsletter
      YAML
    }

    mail = template.mail_preview("fr")
    expect(mail).to include "Salut Bob Dae,"
    expect(mail).to include "Content Title</h2>"
    expect(mail).to include "Example Text Bob Dae"
    expect(mail).not_to include "Second Title/h2>"
    expect(mail).to include "Third Content</p>"
    expect(mail).to include "bla bla</p>"
  end

  specify "send default simple template", sidekiq: :inline do
    template = Newsletter::Template.find_by(title: "Texte simple")
    member = create(:member,
      name: "John Doe",
      emails: "john@doe.com")
    newsletter = create(:newsletter,
      template: template,
      audience: "member_state::pending",
      subject: "Texte simple test",
      blocks_attributes: {
        "0" => { block_id: "text", content_fr: "Hello {{ member.name }}" }
      })

    expect { newsletter.send! }
      .to change { newsletter.deliveries.count }.by(1)

    email = ActionMailer::Base.deliveries.first
    expect(email.subject).to eq "Texte simple test"
    mail_body = email.parts.map(&:body).join
    expect(mail_body).to include "Hello John Doe"
  end

  specify "send default next delivery template", sidekiq: :inline do
    template = Newsletter::Template.find_by(title: "Prochaine livraison")
    member = create(:member, :active, name: "John Doe")
    create(:activity, date: 1.week.from_now)
    create(:activity_participation, member: member)

    newsletter = create(:newsletter,
      template: template,
      audience: "member_state::active",
      subject: "Prochaine livraison test",
      blocks_attributes: {
        "0" => { block_id: "intro", content_fr: "Intro {{ member.name }}!" },
        "2" => { block_id: "events", content_fr: "Marché du fun" },
        "3" => { block_id: "recipe", content_fr: "" }
      })

    expect { newsletter.send! }
      .to change { newsletter.deliveries.count }.by(1)

    email = ActionMailer::Base.deliveries.first
    expect(email.subject).to eq "Prochaine livraison test"
    mail_body = email.parts.map(&:body).join
    expect(mail_body).to include "Intro John Doe!"
    expect(mail_body).not_to include "Contenu panier"
    expect(mail_body).to include "Événements à venir"
    expect(mail_body).to include "Marché du fun"
    expect(mail_body).not_to include "La recette"

    expect(mail_body).to include "Voici les activités à venir pour lesquelles nous avons encore besoin de monde:"
    expect(mail_body).to include "Aide aux champs, Thielle</li>"
    expect(mail_body).to include "En tenant compte de vos inscriptions actuelles"
  end

  specify "send default next delivery template (without ativities)", sidekiq: :inline do
    Current.acp.update!(features: [])
    template = Newsletter::Template.find_by(title: "Prochaine livraison")
    create(:membership)

    newsletter = create(:newsletter,
      template: template,
      audience: "member_state::active",
      subject: "Prochaine livraison test",
      blocks_attributes: {
        "0" => { block_id: "intro", content_fr: "Hello" },
        "2" => { block_id: "events", content_fr: "" },
        "3" => { block_id: "recipe", content_fr: "" }
      })

    expect { newsletter.send! }
      .to change { newsletter.deliveries.count }.by(1)

    email = ActionMailer::Base.deliveries.first
    mail_body = email.parts.map(&:body).join
    expect(mail_body).not_to include "Voici les activités à venir pour lesquelles nous avons encore besoin de monde:"
  end

  specify "send default next delivery template (with basket content)", freeze: "2023-01-01", sidekiq: :inline do
    Current.acp.update!(features: [])
    template = Newsletter::Template.find_by(title: "Prochaine livraison")

    delivery = create(:delivery, date: 1.week.from_now)

    create(:basket_complement, id: 1, name: "Pain")
    create(:basket_complement, id: 2, name: "Oeufs")

    big = create(:basket_size, name: "Grand")
    small = create(:basket_size, name: "Petit")

    membership = create(:membership, basket_size: small)
    basket = membership.next_basket
    basket.update!(baskets_basket_complements_attributes: {
      "0" => { basket_complement_id: 1, quantity: 1 },
      "1" => { basket_complement_id: 2, quantity: 2 }
    })

    create(:basket_content,
      basket_size_ids_percentages: { small.id => 100, big.id => 0 },
      product: create(:product, name: "Carottes"))
    create(:basket_content,
      basket_size_ids_percentages: { small.id => 100, big.id => 0 },
      product: create(:product, name: "Choux-Fleur"))
    create(:basket_content,
      basket_size_ids_percentages: { small.id => 100, big.id => 0 },
      product: create(:product, name: "Céleri"),
      depots: [ create(:depot) ])
    create(:basket_content,
      basket_size_ids_percentages: { small.id => 0, big.id => 100 },
      product: create(:product, name: "Salade"))

    newsletter = create(:newsletter,
      template: template,
      audience: "member_state::active",
      subject: "Prochaine livraison test",
      blocks_attributes: {
        "0" => { block_id: "intro", content_fr: "Hello" },
        "2" => { block_id: "events", content_fr: "" },
        "3" => { block_id: "recipe", content_fr: "" }
      })

    expect { newsletter.send! }
      .to change { newsletter.deliveries.count }.by(1)

    email = ActionMailer::Base.deliveries.first
    mail_body = email.parts.map(&:body).join
    expect(mail_body).to include "Petit PUBLIC:</span>"
    expect(mail_body).to include "Carottes (10.0kg)</li>"
    expect(mail_body).to include "Choux-Fleur (10.0kg)</li>"
    expect(mail_body).not_to include "Céleri"
    expect(mail_body).not_to include "Salade"

    expect(mail_body).to include "Complément(s): 2x Oeufs PUBLIC et Pain PUBLIC</p>"
  end
end
