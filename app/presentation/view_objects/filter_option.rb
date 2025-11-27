# frozen_string_literal: true

require_relative 'activity'

module Views
  # View for all filter options
  class FilterOption
    def initialize(activities)
      @activities = activities || []
    end

    def tags
      @activities.flat_map do |activity|
        Array(activity.tags).map { |tag| tag.tag.to_s }
      end.uniq
    end

    def cities
      @activities.map(&:city).uniq
    end

    def districts
      @activities.group_by(&:city).transform_values do |arr|
        dists = arr.map(&:district).uniq
        ['全區'] + dists
      end
    end
  end
end
