# frozen_string_literal: true

require "test_helper"

class HotCellTest < ActiveSupport::TestCase
  test "describes active_storage cell with expected operations and matching version" do
    description = HotCell.describe_cells.fetch("active_storage")

    assert_equal HotCell::Client::VERSION, description[:server_version]
    assert_operator HotCell.cell("active_storage").timeout, :>=, description[:answer_within]
    assert_includes description[:operations], "active_storage.transformers.image.vips"
    assert_includes description[:operations], "active_storage.analyzers.image.vips"
    assert_includes description[:operations], "organization.logo.process"
  end

  test "analyzes uploaded images through Hot Cell" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo-valid.png").open,
      filename: "logo.png",
      content_type: "image/png")
    blob.analyze

    assert blob.metadata[:analyzed]
    assert_equal 512, blob.metadata[:width]
    assert_equal 512, blob.metadata[:height]
  end

  test "maps permanent unreadable cell failures to CSAAdmin::UnprocessableUpload" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("not a valid png"),
      filename: "corrupt.png",
      content_type: "image/png")

    error = assert_raises(CSAAdmin::UnprocessableUpload) do
      blob.variant(resize_to_limit: [ 32, 32 ]).processed
    end

    assert_kind_of HotCell::Failure::Exception, error
    assert error.hot_cell_failure.permanent?
    assert_equal "unreadable", error.hot_cell_failure.code
  end

  test "maps transient cell outages to CSAAdmin::ConversionTemporarilyUnavailable" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("logo-valid.png").open,
      filename: "logo.png",
      content_type: "image/png")

    previous_root = HotCell.root
    Dir.mktmpdir("hc-down", "/tmp") do |empty_root|
      HotCell.root = empty_root
      error = assert_raises(CSAAdmin::ConversionTemporarilyUnavailable) do
        blob.variant(resize_to_limit: [ 32, 32 ]).processed
      end

      assert_kind_of HotCell::Failure::Exception, error
      assert_not error.hot_cell_failure.permanent?
      assert_equal "unavailable", error.hot_cell_failure.code
    end
  ensure
    HotCell.root = previous_root
  end

  test "AnalyzeJob retries transient Hot Cell failures" do
    handlers = ActiveStorage::AnalyzeJob.rescue_handlers.map(&:first)

    assert_includes handlers, "CSAAdmin::ConversionTemporarilyUnavailable"
  end

  test "app Dockerfile excludes libvips and cell OMP_NUM_THREADS matches deploy cpus" do
    app_dockerfile = Rails.root.join("Dockerfile").read
    cell_dockerfile = Rails.root.join("hotcell/Dockerfile").read
    deploy_cpus = Rails.root.join("config/deploy.yml").read[/activestorage-hotcell:.*?cpus:\s*(\d+)/m, 1]

    assert_no_match(/apt-get install[^\n]*\blibvips/, app_dockerfile)
    assert deploy_cpus.present?
    assert_match(/\bOMP_NUM_THREADS=#{deploy_cpus}\b/, cell_dockerfile)
    assert_match(/\bOMP_THREAD_LIMIT=\d+\b/, cell_dockerfile)
  end
end
