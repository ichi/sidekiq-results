module Sidekiq
  module Results
    class ResultSet < Sidekiq::JobSet
      def initialize
        super LIST_KEY
      end
    end
  end
end
