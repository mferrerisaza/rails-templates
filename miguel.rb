run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# GEMFILE
########################################
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'devise'
    gem 'simple_form'
  RUBY
end

inject_into_file 'Gemfile', after: 'group :development, :test do' do
  <<-RUBY
    gem 'dotenv-rails'
  RUBY
end


inject_into_file 'Gemfile', after: 'group :development do' do
  <<-RUBY
    gem 'hotwire-livereload'
  RUBY
end

# Dev environment
########################################
gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')

# Add flashes
file 'app/views/shared/_flashes.html.erb', <<~HTML
  <% if notice %>
    <div class="w-fit transition duration-150 bg-green-100 rounded-lg p-4 text-sm text-green-800 absolute bottom-4 left-4 mr-8 flex justify-between"
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
    <div class="w-fit transition duration-150 bg-red-100 rounded-lg p-4 text-sm text-red-800 absolute bottom-4 left-4 mr-8 flex justify-between"
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
    generate.orm :active_record, primary_key_type: :uuid
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
  run 'yarn add @tailwindcss/forms'
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

  # Fix devise with turbo
  ########################################
  file 'app/controllers/turbo_controller.rb', <<~RUBY
    class TurboController < ApplicationController
      class Responder < ActionController::Responder
        def to_turbo_stream
          controller.render(options.merge(formats: :html))
        rescue ActionView::MissingTemplate => error
          if get?
            raise error
          elsif has_errors? && default_action
            render rendering_options.merge(formats: :html, status: :unprocessable_entity)
          else
            redirect_to navigation_location
          end
        end
      end

      self.responder = Responder
      respond_to :html, :turbo_stream
    end
  RUBY

  inject_into_file 'config/initializers/devise.rb', before: 'Devise.setup do |config|' do
    <<~RUBY
      # frozen_string_literal: true
      # Turbo doesn't work with devise by default.
      # Keep tabs on https://github.com/heartcombo/devise/issues/5446 for a possible fix
      # Fix from https://gorails.com/episodes/devise-hotwire-turbo
      class TurboFailureApp < Devise::FailureApp
        def respond
          if request_format == :turbo_stream
            redirect
          else
            super
          end
        end

        def skip_format?
          %w(html turbo_stream */*).include? request_format.to_s
        end
      end
    RUBY
  end

  gsub_file('config/initializers/devise.rb', /# config.parent_controller = 'DeviseController'/, "config.parent_controller = 'TurboController'")
  gsub_file('config/initializers/devise.rb', /\# config.navigational_formats = \[\'\*\/\*\'\, \:html\]/, "config.navigational_formats = ['*/*', :html, :turbo_stream]")
  gsub_file('config/initializers/devise.rb', /# config.parent_controller = 'DeviseController'/, "config.parent_controller = 'TurboController'")


  inject_into_file 'config/initializers/devise.rb', after: '# config.warden do |manager|' do
    <<-RUBY
    # Inject here
    config.warden do |manager|
      manager.failure_app = TurboFailureApp
      # manager.intercept_401 = false
      # manager.default_strategies(scope: :user).unshift :some_external_strategy
    end
    RUBY
  end

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
      static values = { waitTime: { type: Number, default: 1000 } }

      connect() {
        this.timeouts = [window.setTimeout(() => this.dismiss(), this.waitTimeValue)]
      }

      disconnect() {
        this.timeouts.forEach((timeout) => window.clearTimeout(timeout))
      }

      dismiss() {
        this.element.classList.add("-translate-x-full")
        this.timeouts.push(window.setTimeout(() => this.element.remove(), 140))
      }
    }
  JS

  rails_command 'stimulus:manifest:update'
  rails_command 'livereload:install'

  git add: '.'
  git commit: "-m 'Initial commit with template from https://github.com/mferrerisaza/rails-templates'"
end
