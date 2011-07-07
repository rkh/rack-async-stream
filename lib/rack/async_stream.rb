require 'stringio'
require 'eventmachine'

module Rack
  class AsyncStream
    class Stream
      include EM::Deferrable

      def self.available
        @classes ||= [FiberStream, ContinuationStream, ThreadStream]
      end

      def self.available?
        @available ||= check
      end

      def self.try_require(lib)
        require lib
      rescue LoadError
      end

      def initialize(body)
        raise "#{self.class} not available" unless self.class.available?
        @body = body
      end

      def respond_to?(*args)
        super or @body.respond_to?(*args)
      end

      def method_missing(method, *args, &block)
        return super unless @body.respond_to? method
        @body.send(method, *args, &block)
      end
    end

    class FiberStream < Stream
      def self.check
        try_require 'fiber'
        include Rubinius if defined? Rubinius and not defined? Fiber
        defined? Fiber
      end

      def each(&block)
        fiber = Fiber.new do
          @body.each do |str|
            block.call(str)
            EM.next_tick { fiber.resume }
            Fiber.yield
          end
          succeed
        end
        fiber.resume
      end
    end

    class ContinuationStream < Stream
      def self.check
        try_require 'continuation'
        defined? callcc
      end

      def each(&block)
        callcc do |outer|
          @body.each do |str|
            block.call(str)
            callcc do |inner|
              EM.next_tick { inner.call }
              outer.call
            end
          end
          succeed
        end
      end
    end

    class ThreadStream < Stream
      def self.check
        require 'thread'
        true
      end

      def each(&block)
        EM.defer do
          @body.each { |str| EM.next_tick { block.call(str) } }
          EM.next_tick { succeed }
        end
      end
    end

    def initialize(app, options = {})
      @app       = app
      @dont_wrap = options[:dont_wrap] || [Array, String, IO, File, StringIO]
      @stream    = options[:stream]    || Stream.available.detect(&:available?)
      @response  = options[:response]  || :async
      @logging   = options[:logging]
    end

    def log(env, message)
      return unless @logging
      if logger = env['rack.logger']
        logger.info(message)
      else
        env['rack.errors'].puts message
      end
    end

    def call(env)
      status, headers, body = @app.call(env)
      if status < 0 or @dont_wrap.include? body.class or !env['async.callback']
        [status, headers, body]
      else
        log env, "Wrapping %p in %p" % [body, @stream]
        stream = @stream.new body
        EM.next_tick { env['async.callback'].call [status, headers, stream] }
        Symbol === @response ? throw(@response) : @response
      end
    end
  end
end
