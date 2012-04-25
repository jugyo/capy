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
        on :w, :webkit, 'use capybara webkit'
      end
      return 1 if opts.help?

      trap('INT') { exit }

      setup_capybara

      @mode = opts.js? ? :javascript : :capybara

      evaluater = Evaluater.new

      evaluater.visit Capybara.app_host if Capybara.app_host

      if args.empty?
        start_shell evaluater
      else
        args.each do |script_file|
          unless File.exists?(script_file)
            puts "No such file: #{script_file}".red
            return 1
          end
          puts "Running: #{script_file} ..."
          result = evaluater.eval_script File.read(script_file), mode
          puts "=> #{result.inspect}".cyan
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

  class Evaluater
    include Capybara::DSL

    def initialize
      if page.driver.respond_to?(:header)
        page.driver.header(
          'user-agent',
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/534.55.3 (KHTML, like Gecko) Version/5.1.5 Safari/534.55.3'
        )
      end
    end

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

    def take_screenshot(png_path = nil)
      png_path = gen_uniq_file_name('Screen Shot', 'png') unless png_path
      case Capybara.current_driver
      when :webkit
        driver.render(png_path)
      else
        browser.save_screenshot(png_path)
      end
      png_path
    end

    def driver
      page.driver
    end

    def browser
      driver.browser
    end

    def host(app_host)
      Capybara.app_host = app_host
    end

    def stop
      Capy.start_shell(self)
    end

    private

    def gen_uniq_file_name(prefix, extension)
      file_name = "#{prefix} #{Time.now}"
      i = 2
      while File.exists?("#{file_name}.#{extension}")
        file_name = if file_name =~ /\(\d+\)$/
            file_name.sub(/\(\d+\)$/, i.to_s)
          else
            file_name + " (#{i})"
          end
        i += 1
      end
      "#{file_name}.#{extension}"
    end
  end
end
