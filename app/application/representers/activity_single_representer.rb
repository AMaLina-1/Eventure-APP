# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Eventure
  module Representer
    # Representer for a single activity
    class ActivitySingle < Roar::Decorator
      include Roar::JSON

      property :serno
      property :name
      property :name_en
      property :location
      property :city
      property :city_en
      property :district
      property :district_en
      property :building
      property :detail
      property :detail_en
      property :organizer
      property :organizer_en
      property :voice
      property :tag
      property :status
      property :likes_count
      property :start_time
      property :duration
      property :relate_url
    end
  end
end
