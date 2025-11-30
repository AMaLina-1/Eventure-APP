# frozen_string_literal: true

require_relative 'activity'

module Views
  # View for a list of activity entities
  class ActivityList
    include Enumerable

    def initialize(activities)
      @activities = (activities || []).map { |activity| Activity.new(activity) }
    end

    def any?
      @activities.any?
    end

    def each(&block)
      @activities.each { |activity| block.call(activity) } if block
    end
  end
end
