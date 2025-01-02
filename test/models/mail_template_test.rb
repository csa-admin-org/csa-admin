# frozen_string_literal: true

require "test_helper"
require 'minitest/autorun'

class MailTemplateTest < ActiveSupport::TestCase
  test "audit subject and content changes" do
    session = sessions(:master)
    Current.session = session
    template = mail_templates(:member_activated)

    assert_difference 'Audit.count', 1 do
      template.update!(
        subject: "Welcome!",
        content: "Hello {{ member.name }}"
      )
    end

    audit = template.audits.last
    assert_equal session, audit.session
    assert_equal "Welcome!", audit.audited_changes["subjects"].last["en"]
    assert_equal "Hello {{ member.name }}", audit.audited_changes["contents"].last["en"]
  end

  test "set default subject and content for all languages" do
    org(languages: %w[en de])
    template = mail_templates(:member_activated)

    assert_equal(
      { "en" => "Welcome!", "de" => "Herzlich willkommen!" },
      template.subjects
    )
    assert_includes template.contents["en"], "<p>EDIT ME!</p>"
    assert_includes template.contents["de"], "<p>MICH BEARBEITEN!</p>"
  end

  test "set always active template" do
    template = mail_templates(:invoice_created)
    assert template.active

    template.active = false
    assert template.active
    assert_equal true, template[:active]
  end

  test "invoice_overdue_notice is not always active" do
    assert Current.org.send_invoice_overdue_notice?
    template = mail_templates(:invoice_overdue_notice)
    assert template.active

    template.active = false
    assert template.active
    assert_equal true, template[:active]

    Current.org.stub(:send_invoice_overdue_notice?, false) {
      assert_not template.active

      template.active = false # override to true
      assert_not template.active
      assert_equal true, template[:active]
    }
  end

  test "validate liquid syntax" do
    template = mail_templates(:member_activated)

    template.subject = "Welcome! {{"
    template.validate
    assert_not template.errors[:subject_en].empty?

    template.content = "Hello {% foo %}"
    template.validate
    assert_not template.errors[:content_en].empty?
  end

  test "validate subject and content presence" do
    template = mail_templates(:member_activated)

    template.subject = ""
    template.validate
    assert_not template.errors[:subject_en].empty?

    template.content = ""
    template.validate
    assert_not template.errors[:content_en].empty?
  end

  test "validate content HTML syntax" do
    template = mail_templates(:member_activated)
    template.content = "<p>Hello<//p>"
    template.validate
    assert_not template.errors[:content_en].empty?
  end

  test "all defaults templates are valid" do
    org(languages: Organization.languages)

    MailTemplate.create_all!
    assert MailTemplate.many?

    MailTemplate.find_each do |template|
      assert template.valid?
    end
  end

  test "delivery_cycle_ids" do
    template = mail_templates(:member_activated)
    c1 = delivery_cycles(:mondays)
    c2 = delivery_cycles(:thursdays)

    template.delivery_cycle_ids = [ c2.id, c1.id ]
    assert_nil template[:delivery_cycle_ids]
    assert_equal [ c1.id, c2.id ].sort, template.delivery_cycle_ids.sort

    template.delivery_cycle_ids = []
    assert_nil template[:delivery_cycle_ids]
    assert_equal [ c1.id, c2.id ].sort, template.delivery_cycle_ids.sort

    template.delivery_cycle_ids = [ c2.id ]
    assert_equal [ c2.id ], template[:delivery_cycle_ids]
    assert_equal [ c2.id ], template.delivery_cycle_ids
  end
end
