require 'rails_helper'

describe Newsletter do
  let(:template) {
    create(:newsletter_template,
      content_fr: <<~LIQUID,
        {% content id: 'first', title: 'First FR' %}
          FIRST CONTENT FR
        {% endcontent %}
        {% content id: 'second' %}
          SECOND CONTENT FR
        {% endcontent %}
      LIQUID
      content_de: <<~LIQUID)
        {% content id: 'first', title: 'First DE' %}
          FIRST CONTENT DE
        {% endcontent %}
        {% content id: 'second' %}
          SECOND CONTENT DE
        {% endcontent %}
      LIQUID
  }

  specify 'validate from hostname' do
    Current.acp.update!(email_default_host: 'https://membres.ragedevert.ch')

    newsletter = build(:newsletter, from: 'info@rave.ch')
    expect(newsletter).not_to have_valid(:from)

    newsletter = build(:newsletter, from: 'contact@ragedevert.ch')
    expect(newsletter).to have_valid(:from)

    newsletter = build(:newsletter, from: nil)
    expect(newsletter).to have_valid(:from)

    newsletter = build(:newsletter, from: '')
    expect(newsletter).to have_valid(:from)
  end

  specify 'validate at least content must be present' do
    newsletter = build(:newsletter, template: template,
      blocks_attributes: {
        '0' => { block_id: 'first', content_fr: '' },
        '1' => { block_id: 'second', content_fr: '' },
      }
    )

    expect(newsletter).not_to have_valid(:blocks)
  end

  specify 'validate same blocks must be present for all languages' do
    Current.acp.update! languages: %w[fr de]
    newsletter = build(:newsletter, template: template,
      blocks_attributes: {
        '0' => {
          block_id: 'first',
          content_fr: 'Hello' ,
          content_de: ''
        },
        '1' => { block_id: 'second', content_fr: '', content_de: '' },
      }
    )

    expect(newsletter).not_to have_valid(:blocks)
    expect(newsletter.errors[:blocks]).to eq ['doit être rempli(e)']
  end

  specify 'mailpreview' do
    Current.acp.update! email_signature: 'Signature'
    newsletter = build(:newsletter, template: template,
      subject: 'Ma Super Newsletter',
      blocks_attributes: {
        '0' => { block_id: 'first', content_fr: 'Hello {{ member.name }}' },
        '1' => { block_id: 'second', content_fr: 'Youpla Boom' },
      }
    )
    newsletter.liquid_data_preview_yamls = {
      'fr' => <<~YAML
        member:
          name: Bob Dae
        subject: Ma Newsletter
      YAML
    }

    mail = newsletter.mail_preview('fr')
    expect(mail).to include 'Ma Super Newsletter</h1>'
    expect(mail).to include 'First FR</h2>'
    expect(mail).to include 'Hello Bob Dae'
    expect(mail).to include 'Youpla Boom'
    expect(mail).to include 'Signature'
  end

  specify 'mailpreview with custom signature' do
    Current.acp.update! email_signature: 'Signature'
    newsletter = build(:newsletter,
      template: template,
      signature: 'Au plaisir')

    mail = newsletter.mail_preview('fr')
    expect(mail).not_to include 'Signature'
    expect(mail).to include 'Au plaisir'
  end

  specify 'mailpreview is using persisted template content and preview data once sent' do
    newsletter = build(:newsletter, template: template,
      subject: 'Ma Super Newsletter',
      blocks_attributes: {
        '0' => { block_id: 'first', content_fr: 'Hello {{ member.name }}' },
        '1' => { block_id: 'second', content_fr: 'Youpla Boom' },
      }
    )
    preview_yamls = {
      'fr' => <<~YAML
        member:
          name: Bob Dae
        subject: Ma Newsletter
      YAML
    }
    newsletter.liquid_data_preview_yamls = preview_yamls

    mail = newsletter.mail_preview('fr')
    expect(mail).to include 'Ma Super Newsletter</h1>'
    expect(mail).to include 'First FR</h2>'
    expect(mail).to include 'Hello Bob Dae'
    expect(mail).to include 'Youpla Boom'

    newsletter.send!

    template.update! content_fr: <<~LIQUID
      {% content id: 'first', title: 'First NEW FR' %}
        FIRST CONTENT FR
      {% endcontent %}
      NEW LINE
      {% content id: 'second' %}
        SECOND CONTENT FR
      {% endcontent %}
    LIQUID

    newsletter = Newsletter.last # hard reload

    expect(newsletter[:liquid_data_preview_yamls]).to eq preview_yamls

    mail = newsletter.mail_preview('fr')
    expect(mail).to include 'Ma Super Newsletter</h1>'
    expect(mail).to include 'First FR</h2>'
    expect(mail).not_to include 'NEW LINE'
    expect(mail).to include 'Hello Bob Dae'
    expect(mail).to include 'Youpla Boom'
  end

  describe '#send!' do
    let(:newsletter) {
      create(:newsletter,
        audience: 'member_state::pending',
        blocks_attributes: {
          '0' => { block_id: 'main', content_fr: 'Hello {{ member.name }}' }
        }
      )
    }

    specify 'send newsletter' do
      create(:member, name: 'Doe', emails: 'john@doe.com, jane@doe.com')
      create(:member, name: 'Bob', emails: 'john@bob.com, jane@bob.com')
      create(:email_suppression, email: 'john@bob.com', stream_id: 'broadcast')

      expect(newsletter.members_count).to eq 2
      expect(newsletter.members.count).to eq 0
      expect(newsletter.emails).to contain_exactly *%w[
        jane@doe.com
        john@doe.com
        jane@bob.com
      ]
      expect(newsletter.suppressed_emails).to eq %w[john@bob.com]
      expect(newsletter.template_contents).to be_empty
      expect(newsletter[:liquid_data_preview_yamls]).to be_empty
      expect(newsletter.audience_names).to be_empty

      expect { newsletter.send! }
        .to change { newsletter.deliveries.count }.by(2)
        .and change { newsletter.sent_at }.from(nil)
        .and change { ActionMailer::Base.deliveries.count }.by(3)

      newsletter = Newsletter.last # hard reload
      expect(newsletter).to be_sent
      expect(newsletter.members_count).to eq 2
      expect(newsletter.members.count).to eq 2
      expect(newsletter.emails).to contain_exactly *%w[
        jane@doe.com
        john@doe.com
        jane@bob.com
      ]
      expect(newsletter.suppressed_emails).to eq %w[john@bob.com]
      expect(newsletter.template_contents).to eq newsletter.template.contents
      expect(newsletter[:liquid_data_preview_yamls]).not_to be_empty
      expect(newsletter.audience_names).to eq(
        'fr' => 'Membres: À valider')
    end
  end
end
