if Rails.env.development?
  begin
  require "rubycritic/rake_task"

  RubyCritic::RakeTask.new do |task|
    # Name of RubyCritic task. Defaults to :rubycritic.

    # Glob pattern to match source files. Defaults to FileList['.'].
    task.paths   = FileList['app/**/*.rb', 'lib/**/*.rb', 'vendor/**/*.rb', 'config/**/*.rb']

    # Defaults to false
    task.verbose = true
  end
  rescue LoadError
    # You don't have rubycritic.
  end
end
