# frozen_string_literal: true

Rails.application.config.to_prepare do
  MissionControl::Jobs.show_console_help = false
end
