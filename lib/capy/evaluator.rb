module Capy

class Evaluator
  include Capybara::DSL

  def initialize
    if page.driver.respond_to?(:header)
      page.driver.header(
        'user-agent',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/534.55.3 (KHTML, like Gecko) Version/5.1.5 Safari/534.55.3'
      )
    end
  end

  def eval_script(script, mode, file_path = nil)
    prev_file, @current_file = @current_file, file_path if file_path
    prev_mode, @current_mode = @current_mode, mode

    case mode
    when :javascript
      javascript script
    else
      capybara script
    end
  ensure
    @current_file = prev_file if file_path
    @current_mode = prev_mode
  end

  def import(file_name)
    script_file = if @current_file
        File.join(File.dirname(@current_file), file_name)
      else
        file_name
      end

    if File.exists?(script_file)
      eval_script(File.read(script_file), @current_mode, script_file)
    else
      raise "No such file: #{script_file}"
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
