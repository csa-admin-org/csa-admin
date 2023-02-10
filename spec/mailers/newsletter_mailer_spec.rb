require 'rails_helper'

describe NewsletterMailer do
  specify '#newsletter_email', freeze: '2022-01-01' do
    template = create(:newsletter_template,
      content: <<~LIQUID)
        Salut {{ member.name }},

        {% content id: 'main', title: "Content Title" %}
          Example Text {{ member.name }}
        {% endcontent %}
      LIQUID

    member = create(:member,
      name: 'John Doe',
      emails: 'john@doe.com, jane@doe.com')
    mail = NewsletterMailer.with(
      template: template,
      subject: 'Ma Newsletter',
      member: member,
      to: 'john@doe.com'
    ).newsletter_email

    expect(mail.subject).to eq 'Ma Newsletter'
    expect(mail.to).to eq ['john@doe.com']
    expect(mail[:from].decoded).to eq 'Rage de Vert <info@ragedevert.ch>'
    expect(mail[:message_stream].to_s).to eq 'broadcast'

    expect(mail.body).to include('Salut John Doe,')
    expect(mail.body).to include('<h2 class="content_title">Content Title</h2>')
    expect(mail.body).to include('Example Text John Doe')
    expect(mail.body).to have_link('Désincription',
      href: "https://membres.ragedevert.ch/newsletters/unsubscribe/909b574ee84d745debcd427c9c8a1f2c")
  end
end
