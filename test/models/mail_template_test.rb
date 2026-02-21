# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class MailTemplateTest < ActiveSupport::TestCase
  test "audit subject and content changes" do
    session = sessions(:ultra)
    Current.session = session
    template = mail_templates(:member_activated)

    assert_difference "Audit.count", 1 do
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
      {
        "en" => "Welcome!",
        "fr" => "Bienvenue!",
        "de" => "Herzlich willkommen!",
        "it" => "Benvenuto/a!",
        "nl" => "Welkom!"
      },
      template.subjects
    )
    assert_includes template.contents["en"], "<p>Your membership is now active.</p>"
    assert_includes template.contents["fr"], "<p>Votre abonnement est maintenant actif.</p>"
    assert_includes template.contents["de"], "<p>Ihr Abonnement ist jetzt aktiv.</p>"
    assert_includes template.contents["it"], "<p>Il vostro abbonamento è ora attivo.</p>"
  end

  test "set always active template" do
    template = mail_templates(:invoice_created)
    assert template.active

    template.active = false
    assert template.active
    assert template[:active]
  end

  test "basket_second_last_trial is inactive when trial_baskets_count < 2" do
    template = mail_templates(:basket_second_last_trial)

    org(trial_baskets_count: 1)
    assert template.inactive?
    assert_not template.active

    org(trial_baskets_count: 2)
    assert_not template.inactive?

    template.active = true
    assert template.active
  end

  test "invoice_overdue_notice is not always active" do
    template = mail_templates(:invoice_overdue_notice)

    Current.org.stub(:bank_connection?, true) {
      assert template.active

      template.active = false
      assert_not template.active
      refute template[:active]
    }

    template.active = true
    assert_not template.active
    assert template[:active]
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
    c3 = delivery_cycles(:all)

    template.delivery_cycle_ids = [ c3.id, c2.id, c1.id ]
    assert_nil template[:delivery_cycle_ids]
    assert_equal [ c1.id, c2.id, c3.id ].sort, template.delivery_cycle_ids.sort

    template.delivery_cycle_ids = []
    assert_nil template[:delivery_cycle_ids]
    assert_equal [ c1.id, c2.id, c3.id ].sort, template.delivery_cycle_ids.sort

    template.delivery_cycle_ids = [ c2.id ]
    assert_equal [ c2.id ], template[:delivery_cycle_ids]
    assert_equal [ c2.id ], template.delivery_cycle_ids
  end
end
