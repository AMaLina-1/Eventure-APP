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
    # plugin :hooks

    # ================== Initialize Session ==================
    # before do
    #   unless session[:filters_initialized]  # nil for the first time
    #     session[:filters] = {
    #       tag: [],
    #       city: nil,
    #       districts: [],
    #       start_date: nil,
    #       end_date: nil
    #     }
    #     result = Eventure::Service::FilteredActivities.new.call(filters: session[:filters])
    #     @filtered_activities = result.success? ? result.value![:filtered_activities] : []

    #     session[:filters_initialized] = true
    #   end
    # end
    # ================== Routes ==================
    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'

      # ================== Initialize Session ==================
      # initialize_filtered_activities
      unless defined?(@filtered_activities) && @filtered_activities
        session[:filters] ||= {
          tag: [],
          city: nil,
          districts: [],
          start_date: nil,
          end_date: nil
        }
      end
      @all_activities = fetched_filtered_activities(session[:filters])
      @filtered_activities = fetched_filtered_activities(session[:filters])
      # ================== Routes ==================
      routing.root do
        view 'intro_where'
        # session[:seen_intro_where] = nil
        # if session[:seen_intro_where]
        #   routing.redirect '/activities'
        # else
        #   session[:seen_intro_where] = true
        #   view 'intro_where'
        # end
      end

      routing.get 'intro_where' do
        view 'intro_where'
      end

      routing.get 'intro_tag' do
        # 先把這次帶進來的條件轉成乾淨 hash（包含 filter_city）
        filters = extract_filters(routing) # => { tag: [...], city: '新竹市', ... }

        # 目前只需要這次送來的條件就好
        session[:filters] = filters

        # all_activities = Eventure::Repository::Activities.all
        # result = Eventure::Service::FilteredActivities.new.call(filters: session[:filters])
        current_activities = fetched_filtered_activities(session[:filters])

        # 若有指定 city，只拿該 city 的活動來產生 tag 選單
        activities_for_options =
          if filters[:city] && !filters[:city].empty?
            current_activities.select { |a| a.city.to_s == filters[:city].to_s }
          else
            current_activities
          end

        @current_filters = Views::Filter.new(filters || {})
        @filter_options  = Views::FilterOption.new(activities_for_options)

        view 'intro_tag',
             locals: view_locals.merge(
               liked_sernos: Array(session[:user_likes]).map(&:to_i)
             )
      end

      # ================== Likes page ==================
      routing.get 'like' do
        liked_sernos = Array(session[:user_likes]).map(&:to_i)
        liked_activities = liked_sernos.map { |serno| Eventure::Repository::Activities.find_serno(serno) }.compact

        view 'like',
             locals: view_locals.merge(
               cards: Views::ActivityList.new(liked_activities),
               liked_sernos: liked_sernos
             )
      end

      # ================== Activities ==================
      routing.on 'activities' do
        routing.is do
          session[:filters] = extract_filters(routing)
          @filtered_activities = fetched_filtered_activities(session[:filters])
          # result = Eventure::Service::FilteredActivities.new.call(filters: session[:filters])

          # if result.failure?
          #   flash[:error] = result.failure
          #   routing.redirect '/activities'
          # else
          #   result = result.value!
          #   @filtered_activities = result[:filtered_activities]
          show_activities
          # end
        end

        # 新增：GET /activities/search?keyword=xxx
        routing.get 'search' do
          # 1) 用 form 做 validation（這裡照老師 pattern：把 form result 直接丟進 service）
          form_result = Eventure::Forms::KeywordInput.new.call(
            keyword: routing.params['keyword']
          )

          result = Eventure::Service::SearchedActivities.new.call(form_result)

          # 2) form 或 service 任一失敗，都在這裡處理
          if result.failure?
            flash[:error] = result.failure
            routing.redirect '/activities'
          else
            search_result = result.value!  # 期望是 { filtered_activities:, all_activities: } 的 Hash

            @filtered_activities = search_result[:filtered_activities]
            show_activities
          end
        end

        routing.post 'like' do
          response['Content-Type'] = 'application/json'
          serno = routing.params['serno'] || routing.params['serno[]']
          session[:user_likes] ||= []

          result = Service::UpdateLikeCounts.new.call(serno: serno.to_i, user_likes: session[:user_likes])

          if result.failure?
            flash[:error] = result.failure
          else
            result = result.value!
            session[:user_likes] = result[:user_likes]
            { serno: serno.to_i, likes_count: result[:like_counts] }.to_json
          end
        end
      end
    end

    # ================== Show Activities ==================
    def show_activities
      @current_filters = Views::Filter.new(session[:filters])
      @filter_options = Views::FilterOption.new(@all_activities)
      view 'home',
           locals: view_locals.merge(
             liked_sernos: Array(session[:user_likes]).map(&:to_i)
           )
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
        total_pages: 1,
        current_page: 1
      }
    end

    def activities
      @activities ||= Eventure::Repository::Activities.all
    end

    def service
      @service ||= Eventure::Services::ActivityService.new
    end

    def fetched_filtered_activities(filters)
      result = Eventure::Service::FilteredActivities.new.call(filters: filters)
      return [] if result.failure?

      response_obj = result.value!  # 這裡拿到 Response::ApiResult
      puts response_obj
      # Array(response_obj.message[:filtered_activities])
      Array(response_obj.message)
    end
  end
end
