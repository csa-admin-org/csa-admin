# frozen_string_literal: true

require "digest"

module CSAAdmin
  class UnprocessableUpload < StandardError; end
  class ConversionTemporarilyUnavailable < StandardError; end
end

HotCell.root = ENV["HOTCELL_ROOT"].presence
if HotCell.root.nil? && Rails.env.development?
  default_root = Rails.root.join("tmp/hotcell-sockets").to_s
  dev_root =
    if File.join(default_root, "active_storage", "control.sock").bytesize > 100
      "/tmp/csa-admin-hc-#{Digest::SHA256.hexdigest(Rails.root.to_s)[0, 8]}"
    else
      default_root
    end
  HotCell.root = dev_root if File.socket?(File.join(dev_root, "active_storage", "work.sock"))
end
HotCell.group = ENV["HOTCELL_GROUP"].presence

HotCell.register "active_storage",
  timeout: 45,
  permanent: CSAAdmin::UnprocessableUpload,
  transient: CSAAdmin::ConversionTemporarilyUnavailable

Rails.application.config.after_initialize do
  HotCell.logger = Rails.logger
  HotCell.describe_cells
end
