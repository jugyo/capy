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
        on :n, :nonstop
      end
      exit if opts.help?

      Capybara.register_driver(:selenium) { |app| Capybara::Selenium::Driver.new(app, :browser => :chrome) }
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

    def start_shell
      require 'readline'
      Readline.completion_proc = lambda do |text|
        (Capybara::DSL.instance_methods + [:exit]).grep /^#{Regexp.quote(text.strip)}/
      end
      evaluater = Evaluater.new
      puts 'Type `exit` to exit'
      while buf = Readline.readline('> ', true)
        case buf.strip
        when 'exit'
          exit
        else
          begin
            result = evaluater.instance_eval(buf)
            puts "=> #{result.inspect}".cyan
          rescue => e
            error e
          end
        end
      end
    end

    def eval_script(script_file)
      Evaluater.new.instance_eval(File.read(script_file), script_file, 1)
    rescue => e
      error e
    ensure
      unless opts.nonstop?
        print 'Press Enter to exit: '.bold
        gets
      end
    end

    private

    def error(e)
      puts "#{e.backtrace[0]} #{e}".red
      puts "\t#{e.backtrace[1..-1].join("\n\t")}".red
    end
  end

  class Evaluater
    include Capybara::DSL
  end
end
