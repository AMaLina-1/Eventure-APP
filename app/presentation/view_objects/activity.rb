# frozen_string_literal: true

module Views
  # View for a single activity entity
  class Activity
    def initialize(activity)
      @activity = activity
    end

    def serno
      @activity.serno
    end

    def name
      @activity.name
    end

    def detail
      @activity.detail || ''
    end

    def location
      "#{@activity.city}#{@activity.district}#{@activity.building}"
    end

    def city
      @activity.city
    end

    def district
      @activity.district
    end

    def voice
      @activity.voice
    end

    def organizer
      @activity.organizer
    end

    def tag_ids
      Array(@activity.tags).map { |t| t.respond_to?(:tag_id) ? t.tag_id : nil }.compact
    end

    def tags
      Array(@activity.tags).map { |t| t.respond_to?(:tag) ? t.tag : t.to_s }
    end

    def relate_data_title
      Array(@activity.relate_data).map { |r| r.respond_to?(:relate_title) ? r.relate_title : nil }.compact
    end

    def relate_data_url
      Array(@activity.relate_data).map { |r| r.respond_to?(:relate_url) ? r.relate_url : nil }.compact
    end

    def start_date
      val = @activity.activity_date.start_time
      return val if val.nil?

      # If API returns a String, try parsing to DateTime; if it's already a Time/DateTime, return as is.
      if val.is_a?(String)
        begin
          require 'date'
          DateTime.parse(val)
        rescue StandardError
          nil
        end
      else
        val
      end
    end

    def end_date
      val = @activity.activity_date.end_time
      return val if val.nil?

      if val.is_a?(String)
        begin
          require 'date'
          DateTime.parse(val)
        rescue StandardError
          nil
        end
      else
        val
      end
    end

    def duration
      @activity.activity_date.duration
    end

    # now = DateTime.now 可能有問題
    def status
      @activity.activity_date.status
    end

    def likes_count
      @activity.likes_count
    end
  end
end
