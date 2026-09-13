# frozen_string_literal: true

require "test_helper"

class SupportTicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "index lists tickets with a clickable subject" do
    ticket = Support::Ticket.create!(
      priority: :medium, subject: "Need help", content: "Opening", admin: admins(:external))
    login admins(:super)

    get support_tickets_path

    assert_response :success
    assert_select "a[data-table-row-action=show]", text: "Need help ❗️"
    assert_select ".action-item-button", text: I18n.t("active_admin.resources.support/ticket.new_model")
    assert_select "a[href=?]", support_ticket_path(ticket)
    assert_select ".index_table td", text: ticket.id.to_s, count: 0
    assert_select ".scopes a.index-button-selected", text: /#{I18n.t("active_admin.resources.support/ticket.scopes.waiting")}/
    assert_select ".status-tag[data-status=waiting]", text: /#{I18n.t("states.support\/ticket.waiting")}/i
    assert_select "th a, th", text: /#{I18n.t("attributes.state")}/
    assert_select "th a", text: Support::Ticket.human_attribute_name(:last_activity_at)
    assert_select "td", text: I18n.l(ticket.last_activity_at, format: :short)
    assert_select "td a", text: admins(:external).name
    assert_select ".support-unknown", count: 0
    assert_select "select[name='q[priority_eq]']" do
      assert_select "option[value=?]", Support::Ticket.priorities[:normal], text: ""
      assert_select "option[value=?]", Support::Ticket.priorities[:medium], text: Support::Ticket::PRIORITY_ICONS[:medium]
      assert_select "option[value=?]", Support::Ticket.priorities[:high], text: Support::Ticket::PRIORITY_ICONS[:high]
    end
    assert_select "select[name='q[admin_id_eq]']" do
      assert_select "option[value=?]", admins(:external).id, text: admins(:external).name
      assert_select "option[value=?]", admins(:super).id, count: 0
    end
  end

  test "index keeps the selected priority filter" do
    Support::Ticket.create!(
      priority: :medium, subject: "Need help", content: "Opening", admin: admins(:external))
    login admins(:super)

    get support_tickets_path, params: { q: { priority_eq: Support::Ticket.priorities[:medium] } }

    assert_response :success
    assert_select "select[name='q[priority_eq]'] option[selected][value=?]",
      Support::Ticket.priorities[:medium]
  end

  test "index greys out tickets with no admin" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    ticket.update_columns(admin_id: nil)
    login admins(:super)

    get support_tickets_path

    assert_response :success
    assert_select ".support-unknown", text: I18n.t("active_admin.unknown")
  end

  test "waiting empty slate invites a new request even when replied tickets exist" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    message = ticket.messages.build(author: "support", body: "Done", via: :app)
    message.skip_notify = true
    message.save!
    login admins(:super)

    get support_tickets_path, params: { scope: "waiting" }

    assert_response :success
    assert_select ".empty-state-title",
      text: I18n.t("active_admin.resources.support/ticket.blank_slate.content")
    assert_select ".empty-state a",
      text: I18n.t("active_admin.resources.support/ticket.new_model")
    assert_select ".empty-state-title.is-empty", count: 0
  end

  test "/support redirects to the new ticket form" do
    login admins(:super)

    get support_path

    assert_redirected_to new_support_ticket_path
  end

  test "create stores referer as context metadata" do
    member = members(:john)
    login admins(:super)

    get new_support_ticket_path, headers: { "HTTP_REFERER" => member_url(member) }

    assert_response :success
    assert_select "textarea[name='support_ticket[context]']", count: 0
    assert_includes response.body, I18n.t("formtastic.hints.support_ticket.html")
    assert_select ".has-many-add"
    assert_select ".fieldset-title", text: Attachment.model_name.human(count: 2), count: 0
    assert_select ".support-ticket-subject-row"
    assert_select "label[for=support_ticket_priority]", count: 0
    assert_select "#support_ticket_subject_input .inline-hints", count: 0
    assert_select "select[name='support_ticket[priority]']" do
      assert_select "option[value=?]", "normal", text: ""
      assert_select "option[value=?]", "medium", text: Support::Ticket::PRIORITY_ICONS[:medium]
      assert_select "option[value=?]", "high", text: Support::Ticket::PRIORITY_ICONS[:high]
    end

    post support_tickets_path, params: {
      support_ticket: {
        priority: "normal",
        subject: "Broken shop",
        html: "<div>Checkout fails</div>"
      }
    }

    ticket = Support::Ticket.order(:id).last
    assert_equal member_url(member), ticket.context
  end

  test "create redirects to show" do
    login admins(:external)

    assert_difference "Support::Ticket.count", 1 do
      post support_tickets_path, params: {
        support_ticket: {
          priority: "normal",
          subject: "Broken shop",
          html: "<div>Checkout fails</div>"
        }
      }
    end

    ticket = Support::Ticket.order(:id).last
    assert_redirected_to support_ticket_path(ticket)
    assert_equal "Checkout fails", ticket.messages.first.body
  end

  test "create accepts high priority from the form enum name" do
    login admins(:external)

    post support_tickets_path, params: {
      support_ticket: {
        priority: "high",
        subject: "Broken shop",
        html: "<div>Checkout fails</div>"
      }
    }

    ticket = Support::Ticket.order(:id).last
    assert_redirected_to support_ticket_path(ticket)
    assert_equal "high", ticket.priority
  end

  test "create with a numeric priority string re-renders instead of raising" do
    login admins(:external)

    assert_no_difference "Support::Ticket.count" do
      post support_tickets_path, params: {
        support_ticket: {
          priority: "2",
          subject: "Broken shop",
          html: "<div>Checkout fails</div>"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "#support_ticket_priority_input.error"
    assert_includes response.body, I18n.t("errors.messages.inclusion")
  end

  test "show includes the thread and reply box" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    login admins(:super)

    get support_ticket_path(ticket)

    assert_response :success
    assert_includes response.body, "Opening"
    assert_select ".admin-columns", count: 0
    assert_select ".support-conversation"
    assert_select ".support-message-files", count: 0
    assert_select ".support-reply-form"
    assert_select ".support-reply-form > fieldset.inputs", count: 0
    assert_select ".support-reply-actions button[type=submit].btn"
    assert_select "trix-editor, input[name='support_message[html]'], textarea[name='support_message[html]']"
    assert_select "a[href=?]", edit_support_ticket_path(ticket), count: 0
    assert_select ".admin-page-status .status-tag[data-status=waiting]"
    assert_select ".has-many-add svg"
    assert_includes response.body, I18n.t("active_admin.has_many_new_attachment")
    assert_select ".support-mark-replied", count: 0
    assert_select ".support-replied-note", count: 0
    assert_select ".support-message-author", text: admins(:external).name
    assert_select ".support-message-author.support-unknown", count: 0
  end

  test "show compacts current-tenant admin urls in the thread" do
    url = "https://admin.acme.test/shop_orders?scope=pending"
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "See #{url}", admin: admins(:external))
    login admins(:super)

    get support_ticket_path(ticket)

    assert_response :success
    assert_select "a.support-app-link", text: Shop::Order.model_name.human(count: 2)
    assert_select "a.support-app-link[href*='shop_orders']"
    assert_select "a.support-app-link[href*='scope=pending']"
  end

  test "show greys out unknown admin authors" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    message = ticket.messages.first
    message.update_columns(admin_id: nil, admin_name: nil)
    login admins(:super)

    get support_ticket_path(ticket)

    assert_response :success
    assert_select ".support-message-author.support-unknown", text: I18n.t("active_admin.unknown")
  end

  test "show inlines image attachments and lists other files" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    message = ticket.messages.first
    image = message.attachments.build
    image.file.attach(
      io: File.open(file_fixture("logo.png")),
      filename: "Screenshot.png",
      content_type: "image/png")
    pdf = message.attachments.build
    pdf.file.attach(
      io: File.open(file_fixture("invoice.pdf")),
      filename: "notes.pdf",
      content_type: "application/pdf")
    message.save!
    login admins(:super)

    get support_ticket_path(ticket)

    assert_response :success
    assert_select ".support-message-images img[alt='Screenshot.png']"
    assert_select ".support-message-files-title", text: Attachment.model_name.human(count: 2)
    assert_select ".support-message-files-title svg"
    assert_select ".support-message-files a", text: /notes.pdf/
    assert_select ".support-message-files a", text: /Screenshot.png/, count: 0
  end

  test "reply posts a support message for ultra" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    login admins(:ultra)

    assert_difference "Support::Message.count", 1 do
      post reply_support_ticket_path(ticket), params: {
        support_message: { html: "<div>Here is the fix</div>" }
      }
    end

    message = ticket.messages.order(:id).last
    assert_equal "support", message.author
    assert_nil message.admin
    assert_redirected_to support_ticket_path(ticket)
  end

  test "reply posts an admin message for org admin" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    login admins(:super)

    post reply_support_ticket_path(ticket), params: {
      support_message: { html: "<div>Jane follows up</div>" }
    }

    message = ticket.messages.order(:id).last
    assert_equal "admin", message.author
    assert_equal admins(:super), message.admin
  end

  test "create is refused in demo" do
    login admins(:super)
    with_demo_tenant do
      assert_no_difference "Support::Ticket.count" do
        post support_tickets_path, params: {
          support_ticket: {
            priority: "normal",
            subject: "Demo",
            content: "Should not send"
          }
        }
      end
    end
    assert_redirected_to new_support_ticket_path
  end

  test "org admin cannot update a ticket" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    login admins(:super)

    patch support_ticket_path(ticket), params: { support_ticket: { subject: "Hacked" } }

    assert_equal "Need help", ticket.reload.subject
  end

  test "ultra sees edit and destroy on show" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    login admins(:ultra)

    get support_ticket_path(ticket)

    assert_response :success
    assert_select "a[href=?]", edit_support_ticket_path(ticket)
    assert_select "form[action=?]", support_ticket_path(ticket)
    assert_select "form[action=?]", mark_as_replied_support_ticket_path(ticket)
  end

  test "ultra can mark a waiting ticket as replied" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    login admins(:ultra)

    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      post mark_as_replied_support_ticket_path(ticket)

      assert_redirected_to support_ticket_path(ticket)
      ticket.reload
      assert ticket.marked_as_replied?
      assert_equal "replied", ticket.state
      get support_ticket_path(ticket)
      assert_select ".support-replied-note", text: /Thibaud/
      assert_select ".support-mark-replied", count: 0
    end
  end

  test "org admin cannot mark a ticket as replied" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    login admins(:super)

    post mark_as_replied_support_ticket_path(ticket)

    assert_redirected_to root_path
    assert_nil ticket.reload.replied_at
    assert_equal "waiting", ticket.state
  end

  test "ultra can update ticket metadata without pinging" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Need help", content: "Opening", admin: admins(:external))
    login admins(:ultra)

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      patch support_ticket_path(ticket), params: {
        support_ticket: { subject: "Renamed", priority: "high", context: "https://example.com" }
      }
    end

    assert_redirected_to support_ticket_path(ticket)
    ticket.reload
    assert_equal "Renamed", ticket.subject
    assert_equal "high", ticket.priority
    assert_equal "https://example.com", ticket.context
  end
end
