require 'readline'
require "capy/version"
require "slop"
require "colored"
require 'capybara/dsl'

module Capy
  class << self
    attr_reader :opts, :mode

    def run(args)
      @opts = Slop.parse!(args, :help => true, :strict => true) do
        banner "capy [script.capy]\n"
        on :b, :browser=, 'chrome, firefox', :default => 'chrome'
        on :j, :js, 'eval script as javascript with -a option'
        on :a, :'app-host=', 'app host'
        on :s, :'stop', 'stop after eval script'
      end
      return 1 if opts.help?

      trap('INT') { exit }

      Capybara.register_driver :selenium do |app|
        Capybara::Selenium::Driver.new(app, :browser => opts[:browser].to_sym)
      end
      Capybara.current_driver = :selenium
      Capybara.app_host = opts[:'app-host']

      @mode = opts.js? ? :javascript : :capybara

      evaluater = Evaluater.new
      evaluater.visit (Capybara.app_host) if Capybara.app_host

      if args.empty?
        start_shell evaluater
      else
        args.each do |script_file|
          unless File.exists?(script_file)
            puts "No such file: #{script_file}".red
            return 1
          end
          puts "Running: #{script_file} ..."
          evaluater.eval_script File.read(script_file), mode
          start_shell evaluater if opts.stop?
        end
      end

      0
    rescue Slop::InvalidOptionError => e
      puts e.message.red
      1
    rescue => e
      error e
      1
    end

    EXIT_COMMANDS = %w(exit quit)

    def start_shell(evaluater)
      return if @_start_shell
      @_start_shell = true

      Readline.completion_proc = lambda do |text|
        (Evaluater.instance_methods - Object.methods + EXIT_COMMANDS).grep(/^#{Regexp.quote(text.strip)}/)
      end

      history_file = File.expand_path('~/.capy_history')
      if File.exists?(history_file)
        File.read(history_file, :encoding => "BINARY").
          encode!(:invalid => :replace, :undef => :replace).
          split(/\n/).
          each { |line| Readline::HISTORY << line }
      end

      while buf = Readline.readline('> ', true)
        unless Readline::HISTORY.count == 1
          Readline::HISTORY.pop if buf.empty? || Readline::HISTORY[-1] == Readline::HISTORY[-2]
        end

        case buf.strip
        when *EXIT_COMMANDS
          File.open(history_file, 'w') do |file|
            lines = Readline::HISTORY.to_a[([Readline::HISTORY.size - 1000, 0].max)..-1]
            file.print(lines.join("\n"))
          end
          return
        else
          begin
            result = evaluater.eval_script(buf, mode)
            puts "=> #{result.inspect}".cyan
          rescue => e
            error e
          end
        end
      end

      @_start_shell = false
    end

    private

    def error(e)
      puts "#{e.backtrace[0]} #{e} (#{e.class})".red
      puts "\t#{e.backtrace[1..-1].join("\n\t")}".red
    end
  end

  class Evaluater
    include Capybara::DSL

    def eval_script(script, mode)
      case mode
      when :javascript
        javascript script
      else
        capybara script
      end
    end

    def javascript(script)
      page.evaluate_script script.sub(/\A#!.*\n/, '')
    end
    alias_method :js, :javascript

    def capybara(script)
      instance_eval script
    end

    def host(app_host)
      Capybara.app_host = app_host
    end

    def stop
      Capy.start_shell(self)
    end
  end
end
