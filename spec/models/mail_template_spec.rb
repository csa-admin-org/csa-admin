# frozen_string_literal: true

require "rails_helper"

describe MailTemplate do
  let(:template) { MailTemplate.find_by(title: "member_activated") }

  specify "audit subject and content changes" do
    session = create(:session, :admin)
    Current.session = session

    expect {
      template.update!(
        subject: "Bienvenue à toi!",
        content: "Hello {{ member.name }}")
    }.to change(Audit, :count).by(1)

    audit = template.audits.last
    expect(audit.session).to eq session
    expect(audit.audited_changes["subjects"].last["fr"]).to eq "Bienvenue à toi!"
    expect(audit.audited_changes["contents"].last["fr"]).to eq "Hello {{ member.name }}"
  end

  specify "set default subject and content for all languages" do
    Current.org.update! languages: %w[fr de]
    expect(template.subjects).to eq(
      "fr" => "Bienvenue!",
      "de" => "Herzlich willkommen!")
    expect(template.contents["fr"]).to include("<p>EDITEZ-MOI!</p>")
    expect(template.contents["de"]).to include("<p>MICH BEARBEITEN!</p>")
  end

  specify "set always active template" do
    template = MailTemplate.find_by(title: "invoice_created")
    expect(template).to be_active

    template.active = false
    expect(template).to be_active
    expect(template[:active]).to eq true
  end

  specify "invoice_overdue_notice is not always active" do
    expect(Current.org.send_invoice_overdue_notice?).to eq true
    template = MailTemplate.find_by(title: "invoice_overdue_notice")
    expect(template).to be_active

    template.active = false
    expect(template).to be_active
    expect(template[:active]).to eq true

    allow(Current.org).to receive(:send_invoice_overdue_notice?).and_return(false)
    expect(template).not_to be_active

    template.active = false
    expect(template).not_to be_active
    expect(template[:active]).to eq true
  end

  specify "validate liquid syntax" do
    template.subject = "Bienvenue! {{"
    expect(template).not_to have_valid(:subject_fr)
    template.content = "Hello {% foo %}"
    expect(template).not_to have_valid(:content_fr)
  end

  specify "validate subject and content presence" do
    template.subject = ""
    expect(template).not_to have_valid(:subject_fr)
    template.content = ""
    expect(template).not_to have_valid(:content_fr)
  end

  specify "validate content HTML syntax" do
    template.content = "<p>Hello<//p>"
    expect(template).not_to have_valid(:content_fr)
  end

  specify "all defaults templates are valid" do
    Current.org.update! languages: Organization.languages
    MailTemplate.create_all!
    MailTemplate.find_each do |template|
      expect(template).to be_valid
    end
  end

  specify "#delivery_cycle_ids" do
    create(:delivery_cycle, id: 2)

    template.delivery_cycle_ids = [ 2, 1 ]
    expect(template[:delivery_cycle_ids]).to be_nil
    expect(template.delivery_cycle_ids).to eq [ 1, 2 ]

    template.delivery_cycle_ids = []
    expect(template[:delivery_cycle_ids]).to be_nil
    expect(template.delivery_cycle_ids).to eq [ 1, 2 ]

    template.delivery_cycle_ids = [ 2 ]
    expect(template[:delivery_cycle_ids]).to eq [ 2 ]
    expect(template.delivery_cycle_ids).to eq [ 2 ]
  end
end
