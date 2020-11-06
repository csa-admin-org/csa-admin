# Disable 'mutliline' support due to poor pasting performance
# see https://github.com/ruby/irb/issues/43
IRB.conf[:USE_MULTILINE] = false

# Helper available in IRB, which helps choosing a ACP to enter.
def enter
  acps = ACP.where('id < 100').order(:id)
  options = acps.map { |acp| "#{acp.id.to_s.rjust(2)}: #{acp.name}" }

  puts "Select ACP context: (empty for no ACP)"
  puts options

  selection = gets.strip.presence
  acp = acps.detect { |acp| acp.id == selection.to_i } if selection

  Apartment::Tenant.reset if Apartment::Tenant.current != 'public'
  if acp
    ACP.enter!(acp.tenant_name)
    puts "Entered #{acp.name} context."
  else
    puts 'No ACP selected.'
  end
end

if Apartment::Tenant.current == 'public'
  # Show ACPs upon start. Prevent output of return value with `;`.
  enter;
end
