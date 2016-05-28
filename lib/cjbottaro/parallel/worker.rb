require "cjbottaro/parallel/result"

module Cjbottaro
  module Parallel
    class Worker

      attr_reader :pr_pipe

      def initialize(options = {}, &block)
        @options = options
        @block = block
        @result_pending = false
        @result = Result.new
        start_work_loop
      end

      def <<(object)
        @result_pending = true
        Marshal.dump(object, @pw_pipe)
      end

      def get_result
        Marshal.load(@pr_pipe).tap{ @result_pending = false }
      end

      # Returns true if #<< was called, but a corresponding #result call
      # has not been called yet. If true, does not guarentee that #result
      # will not block.
      def result_pending?
        !!@result_pending
      end

      def shutdown
        @pr_pipe.close
        @pw_pipe.close
        Process.wait(@pid)
      end

    private

      def start_work_loop
        # cr_pipe denotes "child  read  pipe"
        # pw_pipe deontes "parent write pipe"
        @cr_pipe, @pw_pipe = IO.pipe
        @pr_pipe, @cw_pipe = IO.pipe

        @pid = Process.fork do

          # We don't need the parent pipes in the child.
          @pr_pipe.close
          @pw_pipe.close

          while true
            item = get_item
            if item == Stop
              handle_stop
            else
              handle_work(item)
            end
          end

        end

        # We don't need the child pipes in the parent.
        @cr_pipe.close
        @cw_pipe.close

      end

      def handle_stop
        if @options[:yield_on_done]
          handle_work(Done)
        else
          @result.value = :ok
          @result.exception = nil
          report_result
        end
        terminate
      end

      def handle_work(item)
        @result.value = nil
        @result.exception = nil

        begin
          @result.value = @block.call(item)
        rescue Exception => e
          @result.exception = e
        end

        report_result

        terminate(1) if @result.exception
      end

      def report_result
        Marshal.dump(@result, @cw_pipe)
      rescue Errno::EPIPE
        terminate(1)
      end

      def terminate(code = 0)
        cleanup
        exit(code)
      end

      def cleanup
        @cr_pipe.close
        @cw_pipe.close
      end

      def get_item
        Marshal.load(@cr_pipe)
      rescue EOFError
        terminate(1)
      end

    end
  end
end
