if Rails.env.production?
  # Enhance the precompile step to delete asset files. This can't be done
  # through .slugignore since asset compilation happens after ignored files are
  # removed.
  Rake::Task['assets:precompile'].enhance do
    require 'fileutils'
    FileUtils.rm_rf('node_modules')
  end
end
