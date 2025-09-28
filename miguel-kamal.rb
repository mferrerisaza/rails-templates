# Kamal-ready Rails template with SQLite
#
# Usage:
#   rails new myapp \
#     --database=sqlite3 \
#     --css=tailwind \
#     --javascript=esbuild \
#     -a propshaft \
#     -m https://raw.githubusercontent.com/mferrerisaza/rails-templates/master/miguel-kamal.rb
#
# This template includes:
# - Devise authentication
# - SimpleForm with Tailwind CSS
# - Kamal deployment configuration
# - Thruster HTTP/2 proxy
# - SQLite for production (persistent volumes in Kamal)
# - Tailwind CSS with forms plugin
# - UUID primary keys removed (using default integer IDs for SQLite)

run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# GEMFILE
########################################
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'devise'
    gem 'simple_form'
  RUBY
end

# Rails 8 already includes kamal and thruster, but let's ensure thruster is there
unless File.read('Gemfile').include?('thruster')
  inject_into_file 'Gemfile', before: 'group :development, :test do' do
    <<~RUBY
      gem 'thruster', require: false
    RUBY
  end
end

inject_into_file 'Gemfile', after: 'group :development, :test do' do
  <<-RUBY
    gem 'dotenv-rails'
  RUBY
end



# Dev environment
########################################
gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')

# Add flashes
file 'app/views/shared/_flashes.html.erb', <<~HTML
  <% if notice %>
    <div class="z-[100] w-fit transition duration-150 bg-green-100 rounded-lg p-4 text-sm text-green-800 fixed bottom-4 left-4 mr-8 flex justify-between"
         data-controller="alert"
         data-alert-wait-time-value="2000">
      <p class="font-medium flex">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
        </svg>
        <span class="pl-3"><%= notice %></span>
      </p>
      <button class="pl-16 text-sm font-bold flex justify-end items-center" data-action="click->alert#dismiss">
        <svg class="w-4 h-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  <% end %>

  <% if alert %>
    <div class="z-[100] w-fit transition duration-150 bg-red-100 rounded-lg p-4 text-sm text-red-800 fixed bottom-4 left-4 mr-8 flex justify-between"
         data-controller="alert"
         data-alert-wait-time-value="2000">
      <p class="font-medium flex">
        <svg xmlns="http://www.w3.org/2000/svg"  class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
        </svg>
        <span class="pl-3"><%= alert %></span>
      </p>
      <button class="pl-16 text-sm font-bold flex justify-end items-center" data-action="click->alert#dismiss">
        <svg class="w-4 h-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  <% end %>
HTML

inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do
  <<-HTML
    <%= render 'shared/flashes' %>
  HTML
end

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
    generate.orm :active_record
  end
RUBY


environment generators

########################################
# AFTER BUNDLE
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command 'db:drop db:create db:migrate'

  # Simple form with tailwind installation
  ########################################
  generate('simple_form:install')
  run 'yarn add -D @tailwindcss/forms'
  run 'rm -rf tailwind.config.js'
  run 'rm -rf app/assets/stylesheets/application.tailwind.css'
  run 'curl -L https://raw.githubusercontent.com/mferrerisaza/rails-templates/master/simple_form_tailwind_config/tailwind.config.js > tailwind.config.js'
  run 'curl -L https://raw.githubusercontent.com/mferrerisaza/rails-templates/master/simple_form_tailwind_config/simple_form_tailwind.rb > config/initializers/simple_form_tailwind.rb'
  run 'curl -L https://raw.githubusercontent.com/mferrerisaza/rails-templates/master/simple_form_tailwind_config/overwrite_class_with_error_or_valid_class.rb > config/initializers/overwrite_class_with_error_or_valid_class.rb'
  run 'curl -L https://raw.githubusercontent.com/mferrerisaza/rails-templates/master/simple_form_tailwind_config/application.tailwind.css > app/assets/stylesheets/application.tailwind.css'

  # Generate pages controller
  ########################################
  generate(:controller, 'pages', 'home', '--skip-routes', '--no-test-framework')

  # Routes
  ########################################
  route "root to: 'pages#home'"

  # Git ignore
  ########################################
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Devise install + user
  ########################################
  generate('devise:install')
  generate('devise', 'User')

  # App controller
  ########################################
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
      before_action :authenticate_user!
    end
  RUBY

  # migrate + devise views
  ########################################
  rails_command 'db:migrate'
  generate('devise:views')
  run 'rm -rf app/views/devise'
  run 'curl -L https://github.com/mferrerisaza/rails-templates/raw/master/devise.zip > devise.zip'
  run 'unzip devise.zip -d app/views && rm devise.zip'

  # Pages Controller
  ########################################
  run 'rm app/controllers/pages_controller.rb'
  file 'app/controllers/pages_controller.rb', <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: :home

      def home
      end
    end
  RUBY

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

  # Dotenv
  ########################################
  run 'touch .env'

  # Rubocop
  ########################################
  run 'curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml'

  # Fix puma config
  gsub_file('config/puma.rb', 'pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }', '# pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }')

  # Make flashes dismissable and autocleanable
  file 'app/javascript/controllers/alert_controller.js', <<~JS
    import { Controller } from "@hotwired/stimulus"

    export default class extends Controller {
      static values = {
        waitTime: { type: Number, default: 1000 },
        transitionDuration: { type: Number, default: 140 },
        transition: { type: String, default: '-translate-x-full'}
      }

      connect() {
        this.timeouts = [window.setTimeout(() => this.dismiss(), this.waitTimeValue)]
      }

      disconnect() {
        this.timeouts.forEach((timeout) => window.clearTimeout(timeout))
      }

      dismiss() {
        this.element.classList.add(this.transitionValue)
        this.timeouts.push(window.setTimeout(() => this.element.remove(), this.transitionDurationValue))
      }
    }
  JS

  rails_command 'stimulus:manifest:update'

  # Kamal configuration
  ########################################
  # Rails 8 already runs kamal init and creates config/deploy.yml
  # Just add SQLite volumes to the existing deploy.yml
  gsub_file 'config/deploy.yml', /# volumes:.*?\n.*?# - "\/data\/app-storage:\/rails\/storage"/m, <<-YAML.strip
volumes:
  - "/data/#{File.basename(Dir.pwd)}/storage:/rails/storage"
  - "/data/#{File.basename(Dir.pwd)}/db:/rails/db"
  YAML

  # Rails 8 already generates an optimized Dockerfile
  # Just update it to use Thruster as the server
  if File.exist?('Dockerfile')
    gsub_file 'Dockerfile', 'CMD ["./bin/rails", "server"]', 'CMD ["bundle", "exec", "thrust", "./bin/rails", "server"]'
  end

  # Rails 8 includes health check by default at /up, no need to add it

  # Configure SQLite for production
  gsub_file 'config/database.yml', /production:\s*<<: \*default\s*database:.*/, <<~YAML.strip
    production:
      <<: *default
      database: db/production.sqlite3
      pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
      timeout: 5000
  YAML

  # Update production environment for Kamal and Thruster
  inject_into_file 'config/environments/production.rb', after: 'config.assume_ssl = true' do
    <<~RUBY

      # Trust Thruster proxy
      config.force_ssl = false
      config.assume_ssl = true
    RUBY
  end

  # Create .kamal/secrets file template
  file '.kamal/secrets', <<~SECRETS
    # Kamal secrets - DO NOT COMMIT THIS FILE
    KAMAL_REGISTRY_USERNAME=your-docker-username
    KAMAL_REGISTRY_PASSWORD=your-docker-password
    RAILS_MASTER_KEY=#{File.read('config/master.key').strip}
  SECRETS

  append_file '.gitignore', <<~TXT
    # Ignore Kamal secrets
    .kamal/secrets
  TXT

  git add: '.'
  git commit: "-m 'Initial commit with Kamal-ready template from https://github.com/mferrerisaza/rails-templates'"
end
