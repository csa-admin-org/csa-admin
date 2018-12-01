module SanePatch
  def self.patch(gem_name, version, details: nil)
    gem_spec = Gem.loaded_specs[gem_name]
    patched_version = Gem::Version.new(version)
    raise ArgumentError, "Can't patch unloaded gem #{gem_name}" unless gem_spec

    if gem_spec.version == patched_version
      yield
    else
      message = <<~ERROR
        It looks like the #{gem_name} gem was upgraded.
        There are patches in place that need to be verified.
        Make sure that the patch at #{caller_locations.first} is still needed and working.
      ERROR
      message += "Details: \n #{details}" if details

      raise message
    end
  end
end
