# frozen_string_literal: true

# Skip non-interactive terminal
return unless $stdout.tty?

# Helper available in IRB, which helps choosing a Organization to enter.
def enter
  orgs = Organization.where("id < 100").order(:id)
  options = orgs.map { |org| "#{org.id.to_s.rjust(2)}: #{org.name}" }

  puts "Select Organization context: (empty for none)"
  puts options

  selection = gets.strip.presence
  org = orgs.detect { |org| org.id == selection.to_i } if selection

  Tenant.reset if Tenant.inside?
  if org
    Tenant.switch!(org.tenant_name)
    puts "Entered #{org.name} (#{org.tenant_name}) context."
  else
    puts "No Organization selected."
  end
end

if Tenant.outside?
  # Show Organizations upon start. Prevent output of return value with `;`.
  enter
end
