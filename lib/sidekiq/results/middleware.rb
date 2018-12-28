require 'sidekiq/util'

module Sidekiq
  module Results
    class Middleware
      include Sidekiq::Util

      def call(worker, msg, queue)
        data = {
          queue: queue,
          status: 'busy',
          started_at: Time.now.utc.to_f,
          processor: identity,
        }

        start = msg.merge(data).freeze
        save_result(start)

        yield
      rescue => e
        data.merge!(
          status: 'failed',
          error_class: e.class.name,
          error_message: e.message,
          error_backtrace: e.backtrace,
        )

        raise e
      else
        data.merge!(
          status: 'processed',
        )
      ensure
        data.merge!(
          finished_at: Time.now.utc.to_f,
        )

        finish = msg.merge(data).freeze
        remove_result(start)
        save_result(finish)
      end

      private

      def save_result(msg)
        payload = Sidekiq.dump_json(msg)

        Sidekiq.redis do |conn|
          conn.zadd(LIST_KEY, msg[:started_at], payload)

          unless Sidekiq.results_max_count == false
            conn.zremrangebyrank(LIST_KEY, 0, -(Sidekiq.results_max_count + 1))
          end
        end
      end

      def remove_result(msg)
        payload = Sidekiq.dump_json(msg)

        Sidekiq.redis do |conn|
          conn.zrem(LIST_KEY, payload)
        end
      end
    end
  end
end
