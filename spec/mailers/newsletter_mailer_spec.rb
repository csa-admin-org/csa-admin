require "rails_helper"

describe NewsletterMailer do
  let(:template) {
    create(:newsletter_template,
      content: <<~LIQUID)
        Salut {{ member.name }},

        {% content id: 'main', title: "Content Title" %}
          Example Text {{ member.name }}
        {% endcontent %}
      LIQUID
  }

  specify "#newsletter_email", freeze: "2022-01-01" do
    member = create(:member,
      name: "John Doe",
      emails: "john@doe.com, jane@doe.com")
    membership = create(:membership, member: member)
    mail = NewsletterMailer.with(
      template: template,
      subject: "Ma Newsletter",
      member: member,
      to: "john@doe.com"
    ).newsletter_email

    expect(mail.subject).to eq "Ma Newsletter"
    expect(mail.to).to eq [ "john@doe.com" ]
    expect(mail[:from].decoded).to eq "Rage de Vert <info@ragedevert.ch>"
    expect(mail[:message_stream].to_s).to eq "broadcast"

    expect(mail.body).to include("Salut John Doe,")
    expect(mail.body).to include('<h2 class="content_title">Content Title</h2>')
    expect(mail.body).to include("Example Text John Doe")
    expect(mail.body).to have_link("Désinscription",
      href: %r{https://membres.ragedevert.ch/newsletters/unsubscribe/\w{32}})
  end

  specify "#newsletter_email with attachments" do
    newsletter = create(:newsletter, template: template)
    attachment = Newsletter::Attachment.new
    attachment.file.attach(
      io: File.open(file_fixture("qrcode-test.png")),
      filename: "Un code \"QR\" stylé.png")
    newsletter.update! attachments: [ attachment ]

    mail = NewsletterMailer.with(
      template: template,
      subject: "Ma Newsletter",
      member: create(:member),
      attachments: newsletter.attachments.to_a,
      to: "john@doe.com"
    ).newsletter_email

    expect(mail.attachments.size).to eq 1
    attachment = mail.attachments.first
    expect(attachment.filename).to eq "Un code 'QR' style.png"
    expect(attachment.content_type).to eq "image/png"
  end
end
