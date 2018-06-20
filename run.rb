require_relative 'lib/aaet'
require 'parallel'
require_relative 'generate_reports'
require_relative 'setup/common_setup_methods'
require_relative "setup/android_setup_methods"
require_relative "setup/ios_setup_methods"
require 'pry'
require 'uri'

class Executer < ReportBuilder

  attr_accessor :program_opts, :appium_reset, :platform_setup, :appium_arg, :uuid_arg, :setup
  attr_writer :run

  def initialize settings
    self.program_opts = settings
    generate_instance_variables nil, settings
    if caps_platform == 'android'
      self.platform_setup = AndroidSetup.new settings
      avd = caps_avd rescue nil
      uuid = caps_udid rescue nil
      if avd
        platform_setup.check_emulator caps_avd
        self.appium_arg = "--avd #{caps_avd}"
      elsif uuid
        platform_setup.check_uuid caps_udid
        self.appium_arg = "--udid #{caps_udid}"
      end
    elsif caps_platform == 'ios'
      #placeholder for iOS
      self.platform_setup = IosSetup.new settings
    end

    if options[:resetAppium]
      self.appium_reset = nil
    else
      self.appium_reset = '--no-reset'
    end

    if options_debug
      self.instance_variables.each { |var| puts "#{var}: #{self.instance_variable_get(var)}" }
    end
    self.setup = CommonSetup.new
  end

  def generate_instance_variables(parent, hash)
    #turn options/settings nested hash into instance variables
    hash.each do |key, value|
      if value.is_a?(Hash)
        generate_instance_variables(key, value)
        self.class.send(:attr_accessor, key.to_sym)
        self.instance_variable_set("@#{key}", value)
      else
        if parent.nil?
          self.class.send(:attr_accessor, "#{key}".to_sym)
          self.instance_variable_set("@#{key}", value)
        else
          self.class.send(:attr_accessor, "#{parent}_#{key}".to_sym)
          self.instance_variable_set("@#{parent}_#{key}", value)
        end
      end
    end
  end

  def driver_alive?
    @run.current_activity["message"] != "A session is either terminated or not started"
  end

  def kill_everything
    if caps_platform == "android" and !options_cloud
      Process.kill("HUP", program_opts[:logcat_pid])
      #setup.kill_process "#{@uuid} logcat -v threadtime"
      %x(adb -s #{@uuid} shell settings put global policy_control null*) #put status bar back...
      #system("adb -s #{device[:uuid]} emu kill") if options_emulator and options_kill_emulator
      sleep 1
    end
    driver.quit rescue nil
    unless options_cloud
      pid = Process.getpgid(Process.pid)
      Signal.trap('TERM') { Process.kill('TERM', -pid); exit }
      Signal.trap('INT' ) { Process.kill('INT',  -pid); exit }
      Process.kill("HUP", program_opts[:appium_pid])
    end
  end

  def runner time
    require 'timeout'
    begin
      Timeout.timeout(time) { go }
    rescue Timeout::Error
      puts "\n#{time} Seconds Exceeded!!!\nKilling Driver for #{@uuid}...".red
    end
  end

  def force_device_orientation(orientation)
    desired_orientation = orientation.downcase.to_sym
    begin
      if desired_orientation != driver.orientation.to_sym
        puts "Current orientation: #{driver.orientation.to_sym}"
        puts "Setting device to orientation: #{desired_orientation}"
        driver.rotate desired_orientation
      end
    rescue
      puts "\n#{@uuid}: Cannot rotate device to desired orientation: #{desired_orientation}".red
      puts "Keeping Current orientation: #{driver.orientation}\n".yellow
    end
    driver.orientation.to_s.upcase
  end

  def initialize_driver
    if options_cloud
      local_app_path = caps[:caps][:app]
      caps[:caps][:app] = caps_cloud_app
      cloud_url = caps[:appium_lib][:server_url].insert(7, "#{cloud_user}:#{cloud_key}")
      caps[:caps][:url] = cloud_url
      caps[:appium_lib][:server_url] = cloud_url
    else
      old_url = URI(caps[:caps][:url])
      old_port = old_url.port.to_s
      new_url = old_url.to_s.gsub(old_port, program_opts[:appium_port].to_s) #replace port with parallel process port
      caps[:caps][:url] = new_url
      caps[:appium_lib][:server_url] = new_url
    end
    Appium::Driver.new(caps, true).start_driver
    Appium.promote_appium_methods Object
    caps[:caps][:app] = local_app_path if options_cloud #set app back to local app file for activity parsing later...
    sleep 5
    #update program data...
    @uuid = driver.capabilities["deviceUDID"]
    caps[:caps][:udid] = @uuid
    program_opts[:app_and_device_data] = platform_setup.app_and_device_data @uuid
    @resolution = driver.capabilities["deviceScreenSize"]
    program_opts[:app_and_device_data][:device][:resolution] = @resolution
    program_opts[:app_and_device_data][:activities] = program_opts[:activities] #will need to figure out how to parse iOS activities
    program_opts.delete(:activities)
  end

  def generate_output_dir
    dir_array = [
        run_time,
        "#{program_opts[:app_and_device_data][:app_package]}-v#{program_opts[:app_and_device_data][:app_version]}",
        @resolution,
        "#{@uuid}-#{process}",
        program_opts[:app_and_device_data][:device][:os],
        caps_language,
        @orientation
    ]
    dir = setup.create_directories dir_array
    program_opts[:output_dir] = dir
  end

  def go
    unless options_cloud
      appium_info = setup.start_appium_server(program_opts[:process], appium_reset, appium_arg, run_time)
      program_opts[:appium_pid] = appium_info[:appium_pid]
      program_opts[:appium_port] = appium_info[:appium_port]
      program_opts[:appium_log] = appium_info[:appium_log]
    end
    initialize_driver
    caps[:caps][:desired_orientation] = caps[:caps][:orientation] #set this ignored capabilitiy for reporting later...
    @orientation = force_device_orientation(caps[:caps][:orientation]) #setting in caps does not always change orientation so I'm forcing it...
    options[:orientation] = @orientation
    caps[:caps][:orientation] = @orientation
    generate_output_dir
    @run = Aaet::Runner.new program_opts
    unless options_cloud
      if caps_platform == 'android'
        program_opts[:logcat_pid] = @run.monitor_log_start
      elsif caps_platform == 'ios'
        #placeholder for iOS
        #TODO: do something with iOS...
      end
    end
    begin
      if ["crawler", "monkey"].include? options_mode
        loop { @run.instance_eval(options_mode) }
      else
        @run.instance_eval(options_mode)
      end
    rescue Interrupt
      puts "\nGot Interrupted. Stopping...".red
    ensure
      kill_everything
      if options_mode == "crawler"
        ReportBuilder.new(options_translate, process, program_opts).generate_reports
      end
    end
  end
end

#     puts ""
#     puts "Reset Appium Session: #{reset}"
#     puts "Running locale: #{locale}"
#     puts "Running orientation: :#{orientation}"
#     puts "Translate strings: #{translate}"
#     puts "Replay will stop after #{time} seconds...\n"

def crawler options
  setup = CommonSetup.new
  setup.prep_environment
  settings = setup.format_options options
  settings[:run_time] = Time.now.strftime("%Y.%m.%d.%H.%M")
  output_dir_base = "output/#{settings[:run_time]}"
  Dir.mkdir output_dir_base unless File.exists? output_dir_base
  settings[:output_dir_base] = output_dir_base
  #TODO: https://github.com/celluloid/celluloid #maybe look into replacing parallel gem with this...
  Parallel.each(settings[:caps], in_processes: settings[:caps].count, interrupt_signal: 'TERM') do |caps|
    settings[:process] = Parallel.worker_number #set the current process running...
    settings[:config][:caps] = caps
    if settings[:options][:bothOrientations] and settings[:caps].count > 1
      if settings[:process].even?
        settings[:config][:caps][:caps][:orientation] = "PORTRAIT"
      else
        settings[:config][:caps][:caps][:orientation] = "LANDSCAPE"
      end
    end
    settings.delete :caps
    puts "Testing Languages: #{settings[:options][:language]}"
    settings[:options][:language].shuffle.each do |language|
      puts "Running Language: #{language}"
      settings[:config][:caps][:caps][:language] = language
      Executer.new(settings).runner(settings[:options][:seconds])
      puts "Finished language: #{language}\n"
    end
  end
end

def monkey options
  setup = CommonSetup.new
  setup.prep_environment
  settings = setup.format_options options
  settings[:run_time] = Time.now.strftime("%Y.%m.%d.%H.%M")
  Dir.mkdir "output" unless File.exists? "output"
  output_dir_base = "output/#{settings[:run_time]}"
  Dir.mkdir output_dir_base unless File.exists? output_dir_base
  settings[:output_dir_base] = output_dir_base
  Parallel.each(settings[:caps], in_processes: settings[:caps].count, interrupt_signal: 'TERM') do |caps|
    settings[:process] = Parallel.worker_number #set the current process running...
    settings[:config][:caps] = caps
    if settings[:options][:bothOrientations] and settings[:caps].count > 1
      if settings[:process].even?
        settings[:config][:caps][:caps][:orientation] = "PORTRAIT"
      else
        settings[:config][:caps][:caps][:orientation] = "LANDSCAPE"
      end
    end
    settings.delete :caps
    settings[:config][:caps][:caps][:language] = settings[:options][:language]
    Executer.new(settings).runner(settings[:options][:seconds])
  end
end

def replay options
  puts "\nREPLAY Mode is Experimental. Not 100% to work every time...\n".yellow
  #TODO: create a report with images highlighting each step clicked with ImageMagik in case replay does not work.

  setup = CommonSetup.new
  setup.prep_environment

  config = TomlRB.load_file(options[:config], symbolize_keys: true)
  package_name = config[:caps][:appPackage]
  file = setup.select_run(package_name)
  last_run = setup.symbolize(eval(open(file).read))

  #override last crawl run options with replay options.
  options.each { |k,v| last_run[:options][:options][k] = v }

  setup.load_activities last_run[:activities]

  settings = {
      activities: last_run[:activities],
      options: last_run[:options][:options],
      config: last_run[:options][:config]
  }
  settings[:run_time] = Time.now.strftime("%Y.%m.%d.%H.%M")
  output_dir_base = "output/#{settings[:run_time]}"
  Dir.mkdir output_dir_base unless File.exists? output_dir_base
  settings[:output_dir_base] = output_dir_base
  settings[:last_run_steps] = last_run[:data]
  settings[:process] = 0

  Executer.new(settings).runner(settings[:options][:seconds])
end


#   puts "Reset Appium Session: #{reset}"
#   puts "Running locale: #{locale}"
#   puts "Running orientation: :#{orientation}"
#   puts "Translate strings: #{translate}"
#   puts "Replay will stop after #{time} seconds...\n"
