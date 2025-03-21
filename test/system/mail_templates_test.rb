# frozen_string_literal: true

require "application_system_test_case"

class MailTemplatesTest < ApplicationSystemTestCase
  def iframe(id = "mail_preview_en")
    src = page.find("iframe##{id}")[:srcdoc]
    Capybara::Node::Simple.new(src)
  end

  test "modify and preview" do
    travel_to "2024-01-01"
    mail_template = mail_templates(:member_activated)

    login admins(:super)

    visit mail_template_path(mail_template)
    click_link "Edit"

    check "Send"
    fill_in "Subject", with: "Welcome {{ member.name }}!!"
    fill_in "Content", with: "<p>Basket: {{ membership.basket_size.name }}</p>"

    assert_difference "Audit.count", 1 do
      click_button "Update Automatic email"
    end

    assert_selector "h2[aria-label='Page Title']", text: "Member activated"
    assert_text "Send Yes"

    assert iframe.has_selector?("h1", text: "Welcome Jane Doe!!")
    assert iframe.has_selector?("p", text: "Basket: Medium basket")
  end
end
