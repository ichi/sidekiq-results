module Sidekiq
  module Results
    class WebExtension
      def self.registered(app)
        view_path = File.join(File.expand_path("..", __FILE__), "views")
        locale_path = File.expand_path(File.dirname(__FILE__) + '/locales')

        Sidekiq::Web.settings.locales << locale_path

        app.helpers do
          def status_label(status)
            labels = {
              'busy' => '▶',
              'processed' => '✅',
              'failed' => '❌',
            }
            labels[status]
          end
        end

        app.get '/results' do
          @count = (params[:count] || 25).to_i
          (@current_page, @total_size, @results) = page(LIST_KEY, params[:page], @count, reverse: true)
          @results = @results.map { |msg, score| Sidekiq::SortedEntry.new(nil, score, msg) }

          render(:erb, File.read(File.join(view_path, 'index.html.erb')))
        end

        app.post '/results' do
          redirect("#{root_path}results") unless params['key']

          params['key'].each do |key|
            job = @result = ResultSet.new.fetch(*parse_params(params['key'])).first
            retry_or_delete_or_kill job, params if job
          end

          redirect_with_query("#{root_path}morgue")
        end

        app.get '/results/:key' do
          halt 404 unless params['key']

          @result = ResultSet.new.fetch(*parse_params(params['key'])).first
          redirect("#{root_path}results") unless @result

          render(:erb, File.read(File.join(view_path, 'show.html.erb')))
        end

        app.post "/results/:key" do
          halt 404 unless params['key']

          job = ResultSet.new.fetch(*parse_params(params['key'])).first
          retry_or_delete_or_kill job, params if job
          redirect_with_query("#{root_path}results")
        end

        app.post "/results/all/delete" do
          ResultSet.new.clear
          redirect "#{root_path}results"
        end

        app.get '/filter/results' do
          redirect "#{root_path}results"
        end

        app.post '/filter/results' do
          @results = Sidekiq::Failures::FailureSet.new.scan("*#{params[:substr]}*")
          @current_page = 1
          @count = @total_size = @results.size

          render(:erb, File.read(File.join(view_path, 'index.html.erb')))
        end
      end
    end
  end
end
