set :application, "DCHBX GlueDB"
# set :deploy_via, :remote_cache
# set :sudo, "sudo -u nginx"
set :scm, :git
set :repository,  "https://github.com/dchbx/gluedb.git"
set :branch,      "master"
set :rails_env,   "production"
set :deploy_to,   "/var/www/deployments/gluedb"
set :deploy_via, :copy


set :user, "nginx"
set :use_sudo, false
set :default_shell, "bash -l"

role :web, "10.83.85.127"
role :app, "10.83.85.127"
role :db,  "10.83.85.127", :primary => true        # This is where Rails migrations will run

default_run_options[:pty] = true  # prompt for sudo password, if needed
after "deploy:restart", "deploy:cleanup_old"  # keep only last 5 releases
before 'deploy:assets:precompile', 'deploy:ensure_gems_correct'

namespace :deploy do

  desc "Make sure bundler doesn't try to load test gems."
  task :ensure_gems_correct do
    run "mkdir -p #{release_path}/.bundle"
    run "cp -f #{deploy_to}/shared/.bundle/config #{release_path}/.bundle/config"
    run "cd #{release_path} && bundle install"
    run "cd #{release_path} && bundle exec rails r -e production script/amqp/configure_amqp_topology.rb"
  end

  desc "create symbolic links to project nginx, unicorn and database.yml config and init files"
  task :finalize_update do
    run "rm -f #{release_path}/config/mongoid.yml"
    run "ln -s #{deploy_to}/shared/config/mongoid.yml #{release_path}/config/mongoid.yml"
    run "rm -f #{release_path}/config/exchange.yml"
    run "ln -s #{deploy_to}/shared/config/exchange.yml #{release_path}/config/exchange.yml"
    run "ln -s #{deploy_to}/shared/pids #{release_path}/pids"
    run "rm -rf #{release_path}/log"
    run "ln -s #{deploy_to}/shared/log #{release_path}/log"
    run "ln -s #{deploy_to}/shared/eye #{release_path}/eye"
  end

  desc "Restart nginx and unicorn"
  task :restart, :except => { :no_release => true } do
    sudo "service eye_gluedb reload"
  end

  desc "Start nginx and unicorn"
  task :start, :except => { :no_release => true } do
    run "#{try_sudo} service eye_gluedb quit"
    run "#{try_sudo} service eye_gluedb load"
  end

  desc "Stop nginx and unicorn"
  task :stop, :except => { :no_release => true } do
    run "#{try_sudo} service eye_gluedb stop"
  end

  task :cleanup_old, :except => {:no_release => true} do
    count = fetch(:keep_releases, 5).to_i
    run "ls -1dt #{releases_path}/* | tail -n +#{count + 1} | xargs rm -rf"
  end

end
