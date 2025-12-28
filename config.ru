# frozen_string_literal: true

require_relative 'require_app'
require_app
# require_relative 'config/initializer'

# Trigger initial fetch of activities from API
# Eventure::Initializer.trigger_fetch_activities

run Eventure::App.freeze.app
