require "cjbottaro/parallel/worker"
require "cjbottaro/parallel/result"

module Cjbottaro
  module Parallel
    class Mapper

      DEFAULT_OPTIONS = {
        processes: 2,
        progress: false,
        yield_on_done: false
      }

      def initialize(object, options = {}, &block)
        @enumerator = make_enumerator(object)
        @options = DEFAULT_OPTIONS.merge(options)

        worker_options = @options.select{ |k, v| %i(yield_on_done).include?(k) }
        @workers = @options[:processes].times.map{ Worker.new(worker_options, &block) }

        @idle_workers = @workers.dup
        @busy_workers = {}

        @result = []

        setup_progress_bar if options[:progress]
      end

      def run
        @enumerator.each_with_index do |item, i|
          while !(worker = @idle_workers.shift)
            gather_available_results
          end
          assign_work(item, i, worker)
        end

        gather_remaining_results

        @workers.each{ |w| w << Stop     }
        @workers.each{ |w| get_result(w) }
        @workers.each{ |w| w.shutdown    }

        @result
      end

      def assign_work(item, i, worker)
        worker << item
        @busy_workers[worker.pr_pipe] = [worker, i]
      end

      def gather_available_results
        pipes = @busy_workers.keys
        ready_pipes, _, _ = IO.select(pipes)
        ready_pipes.each do |ready_pipe|
          worker, i = @busy_workers.delete(ready_pipe)
          @idle_workers << worker

          result = get_result(worker)

          @result[i] = result.value unless ignore_result?

          @progress_bar.increment if @progress_bar
        end
      end

      def gather_remaining_results
        while !@busy_workers.empty?
          gather_available_results
        end
      end

    private

      def make_enumerator(object)
        case object
        when Enumerator
          object
        when ->(o){ o.respond_to?(:each) }
          object.each
        else
          raise ArgumentError, "enumerable object expected, got: #{object.inspect}"
        end
      end

      def ignore_result?
        @options[:ignore_result]
      end

      def get_result(worker)
        worker.get_result.tap do |result|
          raise result.exception if result.exception
        end
      end

      def setup_progress_bar
        require "ruby-progressbar"

        if !@enumerator.size
          puts "WARNING: cannot setup progress bar without size"
          return
        end

        progress_options = {
          total: @enumerator.size,
          format: '%t |%E | %B | %a'
        }

        case @options[:progress]
        when String, Symbol
          progress_options[:title] = @options[:progress].to_s
        else
          progress_options[:title] = "Progress"
        end

        @progress_bar = ProgressBar.create(progress_options)
      end

    end
  end
end
