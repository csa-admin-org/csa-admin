# frozen_string_literal: true

require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
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

  test "update redistributes, enqueues a PDF refresh, and redirects to show" do
    invoice = invoices(:other_closed)
    item = invoice_items(:other_closed_item)
    travel 2.seconds

    login admins(:ultra)

    assert_enqueued_jobs 1, only: Billing::InvoiceRefreshJob do
      patch invoice_path(invoice), params: {
        invoice: {
          date: invoice.date,
          items_attributes: {
            "0" => { id: item.id, description: item.description, amount: "25" }
          }
        }
      }
    end

    invoice.reload
    assert_redirected_to invoice_path(invoice)
    assert_equal 25, invoice.amount
    assert invoice.open?
    assert_equal 10, invoice.paid_amount
    assert_not invoice.pdf_current?
  end

  test "show polls the PDF preview while it is stale" do
    enable_invoice_pdf
    invoice = create_other_invoice(amount: 10)
    travel 2.seconds
    invoice.touch
    login admins(:ultra)

    get invoice_path(invoice)

    assert_response :success
    assert_includes response.body, 'data-controller="auto-refresh"'
    assert_includes response.body, "animate-spin"
  end

  test "invalid update does not enqueue a PDF refresh" do
    invoice = invoices(:other_closed)
    item = invoice_items(:other_closed_item)

    login admins(:ultra)

    assert_no_enqueued_jobs only: Billing::InvoiceRefreshJob do
      patch invoice_path(invoice), params: {
        invoice: {
          date: "",
          items_attributes: {
            "0" => { id: item.id, description: item.description, amount: "25" }
          }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_equal 10, invoice.reload.amount
  end

  test "pdf action stays on show while the PDF is stale" do
    enable_invoice_pdf
    invoice = create_other_invoice(amount: 10)
    travel 2.seconds
    invoice.touch
    login admins(:ultra)

    get pdf_invoice_path(invoice)

    assert_redirected_to invoice_path(invoice)
  end
end
