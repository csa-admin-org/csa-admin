# frozen_string_literal: true

require "test_helper"

class Liquid::MemberDropTest < ActiveSupport::TestCase
  test "exposes the recipient email to Liquid" do
    recipient_email = "newsletter-recipient@example.test"
    drop = Liquid::MemberDrop.new(members(:john), email: recipient_email)
    template = Liquid::Template.parse("{% if member.email %}{{ member.email }}{% endif %}")

    assert_equal recipient_email, template.render!(
      "member" => drop,
      strict_variables: true)
    context = Liquid::Context.new
    context.strict_variables = true
    drop.context = context

    assert_raises(Liquid::UndefinedDropMethod) { drop.liquid_method_missing("unknown") }
  end
end
