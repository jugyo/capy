require 'readline'
require "capy/version"
require "slop"
require "colored"
require 'capybara/dsl'

module Capy
  class << self
    attr_reader :opts

    def run(args)
      @opts = Slop.parse!(args, :help => true) do
        banner "capy [script.capy]\n"
        on :b, :browser=, 'chrome, firefox', :default => 'chrome'
      end
      exit if opts.help?

      Capybara.register_driver :selenium do |app|
        Capybara::Selenium::Driver.new(app, :browser => opts[:browser].to_sym)
      end
      Capybara.current_driver = :selenium

      if args.empty?
        start_shell
      else
        args.each do |script_file|
          abort "No such file: #{script_file}".red unless File.exists?(script_file)
          puts "Running: #{script_file} ..."
          eval_script script_file
        end
      end
    end

    def start_shell(evaluater = Evaluater.new)
      return if @_start_shell
      @_start_shell = true

      exit_commands = %w(exit quit)

      Readline.completion_proc = lambda do |text|
        (Evaluater.instance_methods - Object.methods + exit_commands).grep(/^#{Regexp.quote(text.strip)}/)
      end

      history_file = File.expand_path('~/.capy_history')
      if File.exists?(history_file)
        File.read(history_file, :encoding => "BINARY").
          encode!(:invalid => :replace, :undef => :replace).
          split(/\n/).
          each { |line| Readline::HISTORY << line }
      end

      puts 'Type `exit` to exit'

      while buf = Readline.readline('> ', true)
        unless Readline::HISTORY.count == 1
          Readline::HISTORY.pop if buf.empty? || Readline::HISTORY[-1] == Readline::HISTORY[-2]
        end

        case buf.strip
        when *exit_commands
          File.open(history_file, 'w') do |file|
            lines = Readline::HISTORY.to_a[([Readline::HISTORY.size - 1000, 0].max)..-1]
            file.print(lines.join("\n"))
          end
          return
        else
          begin
            result = evaluater.instance_eval(buf)
            puts "=> #{result.inspect}".cyan
          rescue => e
            error e
          end
        end
      end

      @_start_shell = false
    end

    def eval_script(script_file)
      evaluater = Evaluater.new
      evaluater.instance_eval(File.read(script_file), script_file, 1)
    rescue => e
      error e
    end

    private

    def error(e)
      puts "#{e.backtrace[0]} #{e}".red
      puts "\t#{e.backtrace[1..-1].join("\n\t")}".red
    end
  end

  class Evaluater
    include Capybara::DSL

    def host(app_host)
      Capybara.app_host = app_host
    end

    def stop
      Capy.start_shell(self)
    end
  end
end
