# frozen_string_literal: true

require 'roda'
require 'slim'
require 'slim/include'
require_relative '../../presentation/view_objects/activity_list'
require_relative '../../presentation/view_objects/filter'
require_relative '../../presentation/view_objects/filter_option'
require_relative '../services/filtered_activities'
require_relative '../services/update_like_counts'
require_relative '../services/searched_activities'
require_relative '../forms/keyword_input'

module Eventure
  class App < Roda
    plugin :flash
    plugin :render, engine: 'slim', views: 'app/presentation/views_html'
    plugin :static, ['/assets'], root: 'app/presentation'
    plugin :common_logger, $stdout
    plugin :halt
    plugin :caching

    # ================== Routes ==================
    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'

      # response.cache_control public: true, max_age: 300 if App.environment == :production
      response['Vary'] = 'Accept-Language, Cookie'
      response.cache_control private: true, max_age: 300 if App.environment == :production

      # ================== Initialize Session ==================
      session[:filters] ||= {
        tag: [],
        city: nil,
        districts: [],
        start_date: nil,
        end_date: nil
      }
      session[:user_likes] ||= []
      session[:language] ||= 'zh-TW'

      if routing.params['lang']
        session[:language] = routing.params['lang']
      end
      @current_language = session[:language]

      # ================== Routes ==================      
      routing.get 'clear_session' do
        session.clear
        puts 'session cleared'
        routing.redirect '/'
      end

      routing.root do
        App.configure :production do
          response.expires 300, private: true
        end

        # view 'intro_where'

        response['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'

        puts "Fetching activities from API..."
        result = Eventure::Service::ApiActivities.new.call
        # print(result.value!.status)

        # print(result.value!['status'])
        
        processing = Views::FetchingProcessing.new(App.config, result.value!)
        
        # print("subscribing to", `/progress/${processing.ws_channel_id}`);
        puts (processing.in_progress?)
        puts(processing.ws_channel_id)
        puts(processing.ws_route)
        puts(processing.ws_javascript)

        view '/intro_where', locals: { processing: processing }
      end

      routing.get 'intro_where' do
        App.configure :production do
          response.expires 300, private: true
        end
        view 'intro_where'
      end

      routing.get 'intro_tag' do
        @all_activities = fetched_filtered_activities(session[:filters])
        puts "Total activities fetched: #{@all_activities.length}"
      
        # 先把這次帶進來的條件轉成乾淨 hash（包含 filter_city）
        filters = extract_filters(routing) # => { tag: [...], city: '新竹市', ... }

        # 把本次 filters 存回 session，然後立即依照新的 filters 重新向 API 取得活動列表
        session[:filters] = filters

        # 依照剛更新的 filters 重新請求活動，確保 options 是基於目前選取的縣市
        puts 'second fetching filtered activities...'
        activities_for_options = fetched_filtered_activities(filters)
        # @all_activities = activities_for_options
        @filtered_activities = activities_for_options
        puts "Filtered activities count: #{@filtered_activities.length}"

        @current_filters = Views::Filter.new(filters || {})
        @filter_options  = Views::FilterOption.new(activities_for_options)

        view 'intro_tag', locals: view_locals
      end

      # ================== Likes page ==================
      routing.get 'like' do
        @all_activities ||= fetched_filtered_activities(session[:filters])
        liked_sernos = Array(session[:user_likes]).map(&:to_s)
        liked_activities = @all_activities.select { |a| liked_sernos.include?(a.serno.to_s) }

        @filtered_activities = liked_activities
        @current_filters = Views::Filter.new(session[:filters] || {})
        @filter_options  = Views::FilterOption.new(@all_activities || [])

        view 'like', locals: view_locals
      end

      # ================== Activities ==================
      routing.on 'activities' do
        routing.is do
          session[:filters] = extract_filters(routing)
          @filtered_activities = fetched_filtered_activities(session[:filters])
          @all_activities = @filtered_activities
          show_activities
        end

        # 新增：GET /activities/search?keyword=xxx
        routing.get 'search' do
          # 1) 直接把 keyword 以 Hash 傳給 service（Dry::Transaction 期望 Hash 輸入）
          result = Eventure::Service::SearchedActivities.new.call(
            keyword: routing.params['keyword'],
            language: @current_language
          )

          # 2) form 或 service 任一失敗，都在這裡處理
          if result.failure?
            flash[:error] = result.failure
            routing.redirect '/activities'
          else
            activities_list = result.value!

            # 如果 service 回傳的是 Representer::ActivityList（有 .activities），把它轉換為 view 預期的 OpenStruct 格式
            @filtered_activities = if activities_list.respond_to?(:activities)
                                     Array(activities_list.activities).map { |a| map_api_activity(a) }
                                   elsif activities_list.is_a?(Hash)
                                     activities_list[:filtered_activities] || activities_list['filtered_activities'] || []
                                   else
                                     []
                                   end

            @all_activities = @filtered_activities
            show_activities
          end
        end

        routing.post 'like' do
          response['Content-Type'] = 'application/json'
          serno = routing.params['serno'] || routing.params['serno[]']
          serno = serno.to_s.strip
          result = Service::UpdateLikeCounts.new.call(serno: serno, user_likes: session[:user_likes])

          if result.failure?
            response.status = 400
            { error: result.failure }.to_json
          else
            result_value = result.value!
            session[:user_likes] = result_value.user_likes
            # check if this user curreently likes this activity
            user_likes_this = session[:user_likes].map(&:to_s).include?(serno.to_s)
            { serno: result_value.serno, likes_count: result_value.likes_count, user_likes: session[:user_likes],
              is_liked: user_likes_this }.to_json
          end
        end
      end
    end

    # ================== Show Activities ==================
    def show_activities
      @current_filters = Views::Filter.new(session[:filters])
      @filter_options = Views::FilterOption.new(@all_activities)
      view 'home', locals: view_locals
    end

    # 把 params 換成乾淨 hash
    def extract_filters(routing)
      {
        tag: Array(routing.params['filter_tag'] || routing.params['filter_tag[]']).map(&:to_s).reject(&:empty?),
        city: routing.params['filter_city']&.to_s,
        districts: Array(routing.params['filter_district'] || routing.params['filter_district[]'])
          .map(&:to_s).reject(&:empty?),
        start_date: routing.params['filter_start_date']&.to_s,
        end_date: routing.params['filter_end_date']&.to_s
      }
    end

    def view_locals
      {
        cards: Views::ActivityList.new(@filtered_activities),
        all_activities: @all_activities,
        current_filters: @current_filters,
        filter_options: @filter_options,
        liked_sernos: Array(session[:user_likes]).map(&:to_s),
        total_pages: 1,
        current_page: 1
      }
    end

    def fetched_filtered_activities(filters)
      filters_language = filters.merge(language: @current_language)
      result = Eventure::Service::FilteredActivities.new.call(filters: filters_language)
      response_obj = result.value!
      activities = response_obj.activities
      activities.map { |a| map_api_activity(a) }
    end

    # Map a raw activity (from API representer) to the view OpenStruct shape
    def map_api_activity(a)
      raw_tags = a.respond_to?(:tag) ? a.tag : []
      tags = Array(raw_tags).map do |t|
        value = if t.is_a?(Hash)
                  t['tag'] || t[:tag]
                elsif t.respond_to?(:tag)
                  t.tag
                else
                  t
                end
        OpenStruct.new(tag: value)
      end

      use_english = (@current_language == 'en')
      
      get_localized = lambda do |field_name|
        if use_english
          en_method = "#{field_name}_en".to_sym
          en_value = a.respond_to?(en_method) ? a.send(en_method) : nil
          return en_value if en_value && !en_value.to_s.strip.empty?
        end
        a.respond_to?(field_name) ? a.send(field_name) : nil
      end

      OpenStruct.new(
        serno: a.respond_to?(:serno) ? a.serno : nil,
        name: get_localized.call(:name),
        location: a.respond_to?(:location) ? a.location : nil,
        city: get_localized.call(:city),
        district: get_localized.call(:district),
        building: a.respond_to?(:building) ? a.building : nil,
        detail: get_localized.call(:detail),
        organizer: get_localized.call(:organizer),
        voice: a.respond_to?(:voice) ? a.voice : nil,
        tags: tags,
        activity_date: OpenStruct.new(
          start_time: a.respond_to?(:start_time) ? a.start_time : nil,
          end_time: a.respond_to?(:end_time) ? a.end_time : nil,
          duration: a.respond_to?(:duration) ? a.duration : nil,
          status: a.respond_to?(:status) ? a.status : nil
        ),
        likes_count: a.respond_to?(:likes_count) ? a.likes_count : 0
      )
    end
  end
end
