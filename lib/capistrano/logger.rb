module Capistrano
  class Logger #:nodoc:
    attr_accessor :level
    attr_reader   :device

    IMPORTANT = 0
    INFO      = 1
    DEBUG1    = 2
    DEBUG     = 3
    TRACE     = 4
    
    MAX_LEVEL = 4

    def initialize(options={})
      output = options[:output] || $stderr
      if output.respond_to?(:puts)
        @device = output
      else
        @device = File.open(output.to_str, "a")
        @needs_close = true
      end

      @options = options
      @level = 0
    end

    def close
      device.close if @needs_close
    end

    def log(level, message, line_prefix=nil)
      if level <= self.level
        indent = "%*s" % [MAX_LEVEL, "*" * (MAX_LEVEL - level)]
        (RUBY_VERSION >= "1.9" ? message.lines : message).each do |line|
          if line_prefix
            device.puts "#{indent} [#{line_prefix}] #{line.strip}\n"
          else
            device.puts "#{indent} #{line.strip}\n"
          end
        end
      end
    end

    def important(message, line_prefix=nil)
      log(IMPORTANT, message, line_prefix)
    end

    def info(message, line_prefix=nil)
      log(INFO, message, line_prefix)
    end

    def debug(message, line_prefix=nil)
      log(DEBUG1, message, line_prefix)
    end

    def debugx(message, line_prefix=nil)
      log(DEBUG, message, line_prefix)
    end

    def trace(message, line_prefix=nil)
      log(TRACE, message, line_prefix)
    end
  end
end
