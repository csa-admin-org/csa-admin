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
    expect(newsletter.blocks.first.errors[:content_de]).to eq ['doit être rempli(e)']
  end

  specify 'mailpreview' do
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
  end
end
