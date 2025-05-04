require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LiteralVerification
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
    
    # Enable the asset pipeline
    config.assets.enabled = true
    
    # Add additional assets to the asset load path
    config.assets.paths << Rails.root.join('app', 'assets', 'stylesheets')
    config.assets.paths << Rails.root.join('app', 'assets', 'stylesheets', 'components')
    
    # Precompile additional assets
    config.assets.precompile += %w( application.scss )
  end
end
