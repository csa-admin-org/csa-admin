namespace :acps do
  desc 'Set ACPs logo automatically on dev'
  task set_logos: :environment do
    ACP.enter_each! do
      filename = "#{Current.acp.tenant_name}_logo.jpg"
      logo_path = Rails.root.join("spec/fixtures/#{filename}")
      if File.exists?(logo_path)
        Current.acp.logo.attach(io: File.open(logo_path), filename: filename)
      end
    end
  end
end
