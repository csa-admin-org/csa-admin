# frozen_string_literal: true

require "test_helper"

class Support::AppLinkTest < ActiveSupport::TestCase
  test "compacts an admin index url into a labeled button" do
    link = rewrite_link(%(<a href="#{orders_url}">#{orders_url}</a>))

    assert_equal "Orders", link.text
    assert_includes link["class"], "support-app-link"
    assert_includes link["href"], "/shop_orders"
  end

  test "compacts a member show url as Membres #id in French" do
    I18n.with_locale(:fr) do
      link = rewrite_link(%(<a href="#{member_url}">#{member_url}</a>))

      assert_equal "Membres #32", link.text
    end
  end

  test "keeps query string while compacting the label" do
    url = "#{orders_url}?scope=pending&order=created_at_desc"
    link = rewrite_link(%(<a href="#{url}">#{url}</a>))

    assert_equal "Orders", link.text
    assert_includes link["href"], "scope=pending"
  end

  test "rewrites a production admin host to the local host" do
    with_rails_env("development") do
      link = rewrite_link(%(<a href="#{production_orders_url}">#{production_orders_url}</a>))

      assert_equal "https://admin.acme.test/shop_orders", link["href"]
      assert_equal "Orders", link.text
    end
  end

  test "keeps custom link text while rewriting the href" do
    link = rewrite_link(%(<a href="#{member_url}">Pierre</a>))

    assert_equal "Pierre", link.text
    assert_not_includes link["class"].to_s, "support-app-link"
    assert_includes link["href"], "/members/32"
  end

  test "leaves foreign tenant and external links alone" do
    foreign = "https://admin.beta.test/members/1"
    external = "https://example.com/handbook"
    html = Support::AppLink.rewrite(<<~HTML)
      <p><a href="#{foreign}">#{foreign}</a></p>
      <p><a href="#{external}">#{external}</a></p>
    HTML
    links = Nokogiri::HTML.fragment(html).css("a")

    assert_equal foreign, links[0]["href"]
    assert_equal foreign, links[0].text
    assert_equal external, links[1]["href"]
    assert_equal external, links[1].text
  end

  test "compacts when visible text is the encoded url" do
    href = "#{orders_url}?q[_delivery_gid_eq]=gid://csa-admin/Delivery/352"
    text = "#{orders_url}?q%5B_delivery_gid_eq%5D=gid%3A%2F%2Fcsa-admin%2FDelivery%2F352"
    link = rewrite_link(%(<a href="#{href}">#{text}</a>))

    assert_equal "Orders", link.text
    assert_includes link["href"], "_delivery_gid_eq"
  end

  test "rewrites a production members host without compacting" do
    with_rails_env("development") do
      url = "https://members.acme.ch/absences"
      link = rewrite_link(%(<a href="#{url}">#{url}</a>))

      assert_equal url, link.text
      assert_equal "https://members.acme.test/absences", link["href"]
      assert_not_includes link["class"].to_s, "support-app-link"
    end
  end

  test "does not compact urls inside code" do
    link = rewrite_link(%(<pre><code><a href="#{member_url}">#{member_url}</a></code></pre>))

    assert_equal member_url, link.text
    assert_not_includes link["class"].to_s, "support-app-link"
  end

  test "compacts settings hash and edit urls with the section title" do
    I18n.with_locale(:fr) do
      hash = rewrite_link(%(<a href="#{admin_url}/settings#basket_price_extra">#{admin_url}/settings#basket_price_extra</a>))
      edit = rewrite_link(%(<a href="#{admin_url}/settings/basket_price_extra/edit">#{admin_url}/settings/basket_price_extra/edit</a>))

      assert_equal "Paramètres: Prix extra", hash.text
      assert_equal "Paramètres: Prix extra", edit.text
    end
  end

  test "compacts handbook heading urls with page and section" do
    I18n.with_locale(:fr) do
      url = "#{admin_url}/handbook/absence#billing"
      link = rewrite_link(%(<a href="#{url}">#{url}</a>))

      assert_equal "Manuel: Absences > Facturation", link.text
    end
  end

  test "drops a host-only duplicate next to the compacted button" do
    html = <<~HTML
      <p><a href="#{orders_url}">admin.acme.test</a></p>
      <p><a href="#{orders_url}">#{orders_url}</a></p>
    HTML
    links = Nokogiri::HTML.fragment(Support::AppLink.rewrite(html)).css("a")

    assert_equal 1, links.size
    assert_equal "Orders", links.first.text
  end

  test "flattens an Apple Mail rich-link card to one compacted button" do
    url = "#{admin_url}/baskets/15463/edit"
    html = <<~HTML
      <p>Hello</p>
      <div class="apple-rich-link" data-url="#{url}">
        <a class="lp-rich-link" href="#{url}"></a>
        <table>
          <tr>
            <td><a href="#{url}">admin.acme.test</a></td>
            <td><a href="#{url}"><img src="data:image/png;base64,AA=="></a></td>
          </tr>
        </table>
      </div>
    HTML
    links = Nokogiri::HTML.fragment(Support::AppLink.rewrite(html)).css("a")

    assert_equal 1, links.size
    assert_equal "#{Basket.model_name.human(count: 2)} #15463", links.first.text
    assert_includes links.first["href"], "/baskets/15463/edit"
  end

  test "autolinked plaintext admin urls compact through message html" do
    html = Support::AppLink.rewrite(Support::MessageFormat.to_html("See #{orders_url}"))
    link = Nokogiri::HTML.fragment(html).at("a.support-app-link")

    assert link
    assert_equal "Orders", link.text
  end

  private

  def rewrite_link(html)
    Nokogiri::HTML.fragment(Support::AppLink.rewrite(html)).at("a")
  end

  def admin_url
    "https://admin.acme.test"
  end

  def orders_url
    "#{admin_url}/shop_orders"
  end

  def production_orders_url
    "https://admin.acme.ch/shop_orders"
  end

  def member_url
    "https://admin.acme.test/members/32"
  end
end
