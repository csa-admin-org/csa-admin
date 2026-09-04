# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Demo::SeederTest < ActiveSupport::TestCase
  test "raises error when not in demo tenant" do
    error = assert_raises(RuntimeError) do
      Demo::Seeder.new
    end

    assert_equal "Demo::Seeder can only run in a demo tenant", error.message
  end

  test "cohort split covers all current-year active members" do
    assert_equal Demo::Seeder::ACTIVE_MEMBERS_COUNT,
      Demo::Seeder::FOUNDING_MEMBERS_COUNT +
        Demo::Seeder::YEAR_MINUS_ONE_JOINERS_COUNT +
        Demo::Seeder::CURRENT_YEAR_JOINERS_COUNT
  end

  test "seed_fiscal_years spans three years ending at the current FY" do
    travel_to Date.new(2024, 8, 15)
    with_demo_tenant do
      years = Demo::Seeder.new.send(:seed_fiscal_years)

      assert_equal [ 2022, 2023, 2024 ], years.map(&:year)
    end
  end

  test "create_deliveries! builds Tuesday deliveries for three fiscal years" do
    travel_to Date.new(2024, 8, 15)
    with_demo_tenant do
      seeder = Demo::Seeder.new
      seeder.send(:create_delivery_cycles!)
      seeder.send(:create_basket_complements!)
      seeder.send(:create_deliveries!)

      seeder.send(:seed_fiscal_years).each do |fy|
        tuesdays = Delivery.during_year(fy).select { |delivery|
          delivery.date.tuesday? && delivery.date.month.between?(4, 11)
        }
        assert tuesdays.size >= 20, "expected Tuesday deliveries in #{fy.year}, got #{tuesdays.size}"
      end
    end
  end

  test "create_membership! and mark_renewed! link a member across closed years" do
    travel_to Date.new(2024, 8, 15)
    with_demo_tenant do
      seeder = prepare_membership_seeder
      member = seeder.send(:create_member!, state: "active", trial_baskets_count: 0)
      fy_2023 = Current.org.fiscal_year_for(2023)
      fy_2024 = Current.org.fiscal_year_for(2024)

      past = seeder.send(:create_membership!, member, fiscal_year: fy_2023)
      current = seeder.send(:create_membership!, member, fiscal_year: fy_2024, previous: past)
      seeder.send(:mark_renewed!, past, current)

      assert past.reload.renewed_at?
      assert past.renew?
      assert_equal fy_2023.year, past.fy_year
      assert_equal fy_2024.year, current.fy_year
      assert current.basket_size_price > past.basket_size_price
    end
  end

  test "seed_basket_contents! keeps one piece quantity when ratios round down to zero" do
    with_demo_tenant do
      [ 22, 33, 44 ].each_with_index do |price, index|
        BasketSize.create!(
          names: { "en" => "Demo #{index}" },
          public_names: { "en" => "Demo basket #{index}" },
          price: price,
          activity_participations_demanded_annually: 1
        )
      end

      product = BasketContent::Product.create!(
        names: { "en" => "Salad" },
        unit: "pc",
        default_price: 2.5
      )

      seeder = Demo::Seeder.new
      seeder.instance_variable_set(:@products, [ product ])
      seeder.instance_variable_set(:@current_year_deliveries, [ deliveries(:monday_1) ])
      seeder.instance_variable_set(:@all_depots, Depot.all)

      assert_difference -> { BasketContent.count }, 1 do
        seeder.stub(:rand, 1) do
          seeder.send(:seed_basket_contents!)
        end
      end

      content = BasketContent.order(:id).last
      largest_basket_size = BasketSize.order(:price).last

      assert_equal "pc", content.unit
      assert_equal({ largest_basket_size.id => 1 }, content.basket_size_ids_quantities)
    end
  end

  test "seed_basket_contents! always fills the last past delivery and the next one" do
    travel_to Date.new(2024, 4, 10)
    with_demo_tenant do
      last_past = deliveries(:monday_2)
      upcoming = deliveries(:monday_future_1)
      product = BasketContent::Product.create!(
        names: { "en" => "Salad" },
        unit: "pc",
        default_price: 2.5
      )

      seeder = Demo::Seeder.new
      seeder.instance_variable_set(:@products, [ product ])
      seeder.instance_variable_set(:@current_year_deliveries, [
        deliveries(:monday_1), last_past, upcoming
      ])
      seeder.instance_variable_set(:@all_depots, Depot.all)

      seeder.stub(:rand, 1) do
        seeder.send(:seed_basket_contents!)
      end

      assert BasketContent.where(delivery: last_past, product: product).exists?
      assert BasketContent.where(delivery: upcoming, product: product).exists?
    end
  end

  test "ensure_invoice_pdfs_uploaded! re-attaches when the blob row exists but the file does not" do
    enable_invoice_pdf
    with_demo_tenant do
      invoice = create_other_invoice(amount: 10)
      blob = invoice.pdf_file.blob
      blob.service.delete(blob.key)

      assert invoice.pdf_file.attached?
      assert_not blob.service.exist?(blob.key)
      assert invoice.pdf_current?

      Demo::Seeder.new.send(:ensure_invoice_pdfs_uploaded!)
      invoice.reload

      assert invoice.pdf_file.attached?
      assert invoice.pdf_file.blob.service.exist?(invoice.pdf_file.blob.key)
      assert_not_equal blob.id, invoice.pdf_file.blob_id
      assert_not invoice.pdf_stale?
      assert invoice.pdf_current?
      assert invoice.can_send_email?
      assert invoice.pdf_file.download.present?
    end
  end

  test "ensure_invoice_pdfs_uploaded! leaves present invoice PDFs in place" do
    enable_invoice_pdf
    with_demo_tenant do
      invoice = create_other_invoice(amount: 10)
      blob_id = invoice.pdf_file.blob_id

      Demo::Seeder.new.send(:ensure_invoice_pdfs_uploaded!)
      invoice.reload

      assert_equal blob_id, invoice.pdf_file.blob_id
      assert invoice.pdf_file.blob.service.exist?(invoice.pdf_file.blob.key)
      assert invoice.pdf_current?
      assert invoice.can_send_email?
    end
  end

  private

  def prepare_membership_seeder
    farm = depots(:farm)
    seeder = Demo::Seeder.new
    seeder.instance_variable_set(:@small, basket_sizes(:small))
    seeder.instance_variable_set(:@medium, basket_sizes(:medium))
    seeder.instance_variable_set(:@large, basket_sizes(:large))
    seeder.instance_variable_set(:@farm_depot, farm)
    seeder.instance_variable_set(:@market_depot, farm)
    seeder.instance_variable_set(:@home_depot, farm)
    seeder.instance_variable_set(:@all_depots, [ farm ])
    seeder.instance_variable_set(:@all_complements, [ basket_complements(:eggs) ])
    seeder
  end
end
