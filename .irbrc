# Skip non-interactive terminal
return unless $stdout.tty?

# Helper available in IRB, which helps choosing a ACP to enter.
def enter
  acps = ACP.where('id < 100').order(:id)
  options = acps.map { |acp| "#{acp.id.to_s.rjust(2)}: #{acp.name}" }

  puts "Select ACP context: (empty for no ACP)"
  puts options

  selection = gets.strip.presence
  acp = acps.detect { |acp| acp.id == selection.to_i } if selection

  Tenant.reset if Tenant.inside?
  if acp
    ACP.enter!(acp.tenant_name)
    puts "Entered #{acp.name} context."
  else
    puts 'No ACP selected.'
  end
end

if Tenant.outside?
  # Show ACPs upon start. Prevent output of return value with `;`.
  enter;
end
