require 'readline'
require "capy/version"
require "slop"
require "colored"
require 'capybara/dsl'
require 'capy/evaluator'

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
        on :w, :webkit, 'use capybara webkit'
      end
      return 1 if opts.help?

      trap('INT') { exit }

      setup_capybara

      @mode = opts.js? ? :javascript : :capybara

      evaluator = Evaluator.new

      evaluator.visit Capybara.app_host if Capybara.app_host

      if args.empty?
        start_shell evaluator
      else
        script_file = args.shift
        unless File.exists?(script_file)
          puts "No such file: #{script_file}".red
          return 1
        end
        result = evaluator.eval_script File.read(script_file), mode, script_file
        puts "=> #{result.inspect}".cyan
        start_shell evaluator if opts.stop?
      end

      0
    rescue Slop::InvalidOptionError => e
      puts e.message.red
      1
    rescue => e
      error e
      1
    end

    def setup_capybara
      if opts.webkit?
        require 'capybara-webkit'
        Capybara.register_driver :webkit do |app|
          Capybara::Driver::Webkit.new(app, :browser => Capybara::Driver::Webkit::Browser.new)
        end
        Capybara.current_driver = :webkit
      else
        Capybara.register_driver :selenium do |app|
          Capybara::Selenium::Driver.new(app, :browser => opts[:browser].to_sym)
        end
        Capybara.current_driver = :selenium
      end
      Capybara.app_host = opts[:'app-host']
    end

    EXIT_COMMANDS = %w(exit quit)

    def start_shell(evaluator)
      return if @_start_shell
      @_start_shell = true

      Readline.completion_proc = lambda do |text|
        (Evaluator.instance_methods - Object.methods + EXIT_COMMANDS).grep(/^#{Regexp.quote(text.strip)}/)
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
            result = evaluator.eval_script(buf, mode)
            puts "=> #{result.inspect}".cyan
          rescue Exception => e
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
end
