# =============================================================================
# Kona - A Lean BDD Workflow for Rails
# =============================================================================

gsub_file "Gemfile", /gem "selenium-webdriver"/, "# gem \"selenium-webdriver\" # Replaced by Playwright for improved reliability."

gem_group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "guard-rspec"
end

gem_group :test do
  gem "playwright-ruby-client"
  gem "shoulda-matchers"
end

after_bundle do
  remove_dir "test"
  generate "rspec:install"

  gsub_file "spec/spec_helper.rb", /^=begin$/, ""
  gsub_file "spec/spec_helper.rb", /^=end$\n/, ""
  gsub_file "spec/spec_helper.rb",
            "# The settings below are suggested to provide a good initial experience",
            "  # The settings below are suggested to provide a good initial experience"
  gsub_file "spec/spec_helper.rb",
            "# with RSpec, but feel free to customize to your heart's content.",
            "  # with RSpec, but feel free to customize to your heart's content."
  gsub_file "spec/spec_helper.rb",
            "  config.profile_examples = 10",
            "  # config.profile_examples = 10 # Disabled for a more concise test output."

  gsub_file "spec/rails_helper.rb",
            "# Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }",
            "Rails.root.glob(\"spec/support/**/*.rb\").sort_by(&:to_s).each { |f| require f }"

  say "\n🎭 Installing Playwright", :magenta
  run <<~SH
    export PLAYWRIGHT_CLI_VERSION=$(bundle exec ruby -e "require 'playwright'; puts Playwright::COMPATIBLE_PLAYWRIGHT_VERSION.strip") && \\
    (npm install playwright@$PLAYWRIGHT_CLI_VERSION || npm install playwright@next) && \\
    ./node_modules/.bin/playwright install
  SH

  create_file "spec/support/shoulda_matchers.rb", <<~RUBY
    Shoulda::Matchers.configure do |config|
      config.integrate do |with|
        with.test_framework :rspec
        with.library :rails
      end
    end
  RUBY

  create_file "spec/support/factory_bot.rb", <<~RUBY
    RSpec.configure do |config|
      config.include FactoryBot::Syntax::Methods
    end
  RUBY

  # Disable Rails' default system test screenshots. We use Playwright's.
  create_file "spec/support/disable_rails_screenshot.rb", <<~RUBY
    require "action_dispatch/system_testing/test_helpers/screenshot_helper"
    module ActionDispatch::SystemTesting::TestHelpers::ScreenshotHelper
      def take_failed_screenshot; end
    end
  RUBY

  create_file "spec/support/playwright_with_capybara_server.rb", <<~'RUBY'
    require "capybara"
    require "playwright"
    require "playwright/test"

    module Playwright
      class AssertionError
        alias_method :full_message, :message
      end
    end

    Playwright::Test.expect_timeout = 2000

    module PlaywrightHelpers
      def page
        @playwright_page
      end
    end

    # Null Driver to boot the Rails server via Capybara without a browser.
    class CapybaraNullDriver < Capybara::Driver::Base
      def needs_server?; true; end
    end
    Capybara.register_driver(:null) { CapybaraNullDriver.new }

    # Share one browser instance across all tests
    module PlaywrightBrowser
      class << self
        attr_reader :browser

        def start!
          @fiber = Fiber.new do
            Playwright.create(playwright_cli_executable_path: './node_modules/.bin/playwright') do |playwright|
              playwright.chromium.launch(headless: !ENV["BROWSER"]) do |browser|
                Fiber.yield(browser)
              end
            end
          end
          @browser = @fiber.resume
        end

        def stop!
          @fiber.resume if @fiber&.alive?
        end
      end
    end

    RSpec.configure do |config|
      config.before(:suite) do
        FileUtils.mkdir_p("tmp/playwright_screenshots")
        PlaywrightBrowser.start!
      end

      config.after(:suite) do
        PlaywrightBrowser.stop!
      end

      config.around(:each, type: :system) do |example|
        Capybara.current_driver = :null
        base_url = Capybara.current_session.server.base_url

        PlaywrightBrowser.browser.new_context(baseURL: base_url) do |browser_context|
          browser_context.enable_debug_console! if ENV["BROWSER"]
          @playwright_page = browser_context.new_page
          @playwright_page.set_default_timeout(2000)
          example.run
        end
      end

      config.after(:each, type: :system) do |example|
        if example.exception
          timestamp = Time.now.strftime("%Y-%m-%d-%H-%M-%S")
          safe_name = example.full_description.gsub(/[^\w\s-]/, "")[0..60].strip.tr(" ", "_").presence || "failure"
          path = "tmp/playwright_screenshots/error_#{safe_name}_#{timestamp}.png"

          if defined?(@playwright_page) && @playwright_page && !@playwright_page.closed?
            page.screenshot(path: path, fullPage: true)

            example.metadata[:extra_failure_lines] ||= []
            example.metadata[:extra_failure_lines] << "  Screenshot: #{path}"
          end
        end
      end

      config.include PlaywrightHelpers, type: :system
      config.include Playwright::Test::Matchers, type: :system
    end
  RUBY

create_file "Guardfile", <<~'RUBY'
    guard :rspec, cmd: "bundle exec rspec --format progress" do
      require "guard/rspec/dsl"
      dsl = Guard::RSpec::Dsl.new(self)

      watch(%r{^spec/.+_spec\.rb$})

      watch("spec/spec_helper.rb")  { "spec" }
      watch("spec/rails_helper.rb") { "spec" }

      rails = dsl.rails

      watch(rails.controllers) do |m|
        [
          "spec/system/#{m[1]}_spec.rb",
          "spec/requests/#{m[1]}_spec.rb"
        ]
      end

      watch(rails.view_dirs) { |m| "spec/system/#{m[1]}_spec.rb" }

      dsl.watch_spec_files_for(rails.app_files)
    end
  RUBY

  create_file "spec/support/custom_matchers.rb", <<~'RUBY'
    RSpec::Matchers.define_negated_matcher :not_change, :change
  RUBY

  append_to_file ".gitignore", "\n# Kona workflow artifacts\n/node_modules\n/tmp/playwright_screenshots\n"

  say "\n"
  say set_color("⛈️  Kona", :bold, :green)
  say set_color("   A Lean BDD Workflow for Rails", :white)
  say set_color("   ────────────────────────────────────────────────────────", :green)
  say "\n"

  say set_color("   WHAT'S NEXT?", :yellow, :bold)
  say set_color("   ────────────", :yellow)
  say "\n"

  say set_color("   1. Prepare Browsers (one-time setup)", :bold)
  say set_color("      Installs the system dependencies required by Playwright.", :white)
  say set_color("      $ cd #{app_name} && sudo ./node_modules/.bin/playwright install-deps", :cyan)
  say "\n"

  say set_color("      💡 Tip for NVM users:", :yellow)
  say set_color("         If 'sudo' can't find 'node', run this:", :white)
  say set_color("         $ sudo ln -s \"$(which node)\" /usr/local/bin/node", :cyan)
  say "\n"

  say set_color("   2. Enter the Flow", :bold)
  say set_color("      Launch Guard for an instant feedback loop.", :white)
  say set_color("      It will run your specs automatically on every file save.", :white)
  say set_color("      $ bundle exec guard", :cyan)
  say "\n"

  say set_color("   3. The Kona Cycle", :bold)
  say "      1. " + set_color("Determine", :white, :bold) + " the next most important behavior."
  say "      2. " + set_color("Red:", :red, :bold) + " Describe it with an example and watch it fail."
  say "      3. " + set_color("Green:", :green, :bold) + " Write the simplest code to make the example pass."
  say "      4. " + set_color("Refactor:", :cyan, :bold) + " Improve the design without altering behavior."
  say "\n"

  say set_color("   Storm is coming. Stay in the flow. 🦥⛈️", :bold, :green)
  say "\n"
end