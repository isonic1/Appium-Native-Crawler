require 'curb'
require 'toml-rb'
require 'colorize'
require 'pry'
require 'redic'
require 'highline'

class CommonSetup

  attr_accessor :redis, :cli

  def initialize
    self.redis = Redic.new
    self.cli = HighLine.new
  end

  def kill_process process
    `ps -ef | grep #{process} | awk '{print $2}' | xargs kill >> /dev/null 2>&1`
  end

  def kill_processes process
    pids = (`ps -ef | grep #{process} | awk '{print $2}'`).split("\n")
    pids.each { |pid| `kill -9 #{pid} >> /dev/null 2>&1` }
  end

  def wait_for_appium_server port
    loop.with_index do |_, count|
      break if `lsof -i:#{port}`.to_s.length != 0
      if count * 5 > 30
        fail "Invoke Appium server timed out"
      end
      sleep 5
    end
  end

  def start_appium_server process, reset_session, device, date_dir
    process = process
    port = "472#{process}".to_i
    bp = "225#{process}".to_i
    appium_log = "./output/#{date_dir}/appium-#{process}.log"
    pid = spawn("appium #{reset_session} --port #{port} -bp #{bp} #{device} --log #{appium_log} --device-ready-timeout 60 --tmp /tmp/#{process}", :out=>"/dev/null")
    wait_for_appium_server port
    { appium_pid: pid, appium_port: port, appium_log: appium_log }
  end

  def clear_redis
    puts "\nClearing Redis DB..\n"
    redis.call "FLUSHALL"
  end

  def prep_environment
    kill_processes "appium"
    kill_processes "logcat"
    clear_redis
  end

  def cleanup_screenshots
    print_debug "Cleaning files in: #{dir}"
    #add ruby remove dir method
    `rm -rf #{dir}/*`
  end

  def create_output_directory name, time
    Dir.mkdir name unless File.exists? name
    output_dir_base = "#{name}/#{time}"
    Dir.mkdir output_dir_base unless File.exists? output_dir_base
    return output_dir_base
  end

  def create_directories dir_data
    start_dir = Dir.pwd
    Dir.mkdir "output" unless File.exists? "output"
    Dir.chdir "output"
    dir_data.each do |d|
      Dir.mkdir d unless File.exists? d
      Dir.chdir d
    end
    dir = Dir.pwd
    Dir.chdir start_dir
    dir
  end

  def format_options options
    config = TomlRB.load_file(options[:config], symbolize_keys: true)
    app_caps = config[:caps]
    app_caps[:orientation] = options[:orientation].to_s.upcase #make sure orientation is always an upcased string...
    app_caps[:platform] = app_caps[:platform].downcase #make sure platform is always downcased...

    if options[:cloud] #get cloud device capabilities
      cloud_caps  = TomlRB.load_file(config[:cloud][:caps_path], symbolize_keys: true)
      app = upload_app_to_cloud(config)
      cloud_caps[:common_caps][:cloud_app] = app
      app_caps.delete(:deviceName)
      caps = cloud_caps.map { |device_caps| { caps: device_caps[1].merge!(cloud_caps[:common_caps]).merge!(app_caps) } if device_caps.to_s.include? "Device" }.compact
      capabilities = caps.each { |cap| cap.merge!({:appium_lib=>cloud_caps[:appium_lib], :wait=> 0}) }
    else #get local device capabilities
      if options[:emulator]
        emulators = options[:emulator].join.split
        emulator_caps = emulators.map do |emulator|
          { caps: app_caps }.merge!(avd: emulator).merge!({:appium_lib=>{:server_url=>app_caps[:url], :wait=> 0}})
        end
      end

      if options[:uuid]
        devices = options[:uuid].join.split
        device_caps = devices.map do |device|
          { caps: app_caps }.merge!(udid: device).merge!({:appium_lib=>{:server_url=>app_caps[:url], :wait=> 0}})
        end
      end
      capabilities = [emulator_caps, device_caps].compact.flatten
    end

    #convert language string to array. e.g. -l "en fr de" -> ["en", "fr", "de"]
    options[:language] = options[:language].join.split unless options[:mode] == "monkey"

    #Load App Activities
    #TODO: Figure out out to parse iOS app activities.
    if app_caps[:platform] == 'android'
      activities = get_android_activities app_caps[:app], app_caps[:appPackage]
      load_activities activities
    elsif app_caps[:platform] == 'ios'
      #placeholder for ios activities
    end

    { activities: activities, options: options, config: config, caps: capabilities }
  end

  def add_activity activity
    redis.call "LPUSH", "activities", activity
  end

  def load_activities activities
    puts "\nApp Activities: "
    ap activities
    activities.each { |a| add_activity a }
    puts "\n"
  end

  def get_android_activities app, package
    data = ApkXml.new app
    data.parse_xml("AndroidManifest.xml", false, true)
    activities = []
    data.xml_elements.each do |x|
      x.attributes.each do |y|
        activities << y.value if y.value.include? "Activity"
      end
    end
    activities.find_all { |x| x.include? package }.uniq
    activities.map { |x| x.gsub(package, "") }.uniq
  end

  def report_dir
    "#{Dir.pwd}/runs"
  end

  def get_run_reports package_name
    runs = Dir.glob("#{report_dir}/*").find_all { |r| r.include? package_name }
    runs.sort_by { |r| r.match(/#{report_dir}\/(.*)d*-/)[1].split("-")[0] }
  end

  def select_run package_name
    reports = get_run_reports(package_name)
    puts ""
    cli.choose do |menu|
      menu.prompt = "Please Choose a Test Run:  "
      menu.choices(*reports) do |chosen|
        puts "\nTest Chosen: #{chosen}\n".yellow
        return chosen
      end
    end
  end

  def symbolize(obj)
    return obj.reduce({}) do |memo, (k, v)|
      memo.tap { |m| m[k.to_sym] = symbolize(v) }
    end if obj.is_a? Hash

    return obj.reduce([]) do |memo, v|
      memo << symbolize(v); memo
    end if obj.is_a? Array

    obj
  end

  def upload_app_to_cloud config
    if !config[:cloud][:service] == "saucelabs"
      puts "\nCurrently only Sauce Labs ('saucelabs') is supported\n".red
      abort
    end
    app = config[:caps][:zippedApp]
    filename = File.basename(app)
    puts "Uploading App to Sauce Labs: #{app}"
    url = "https://saucelabs.com/rest/v1/storage/#{config[:cloud][:user]}/#{filename}?overwrite=true"
    c = Curl::Easy.new(url)
    c.http_auth_types = :basic
    c.username = config[:cloud][:user]
    c.password = config[:cloud][:key]
    c.multipart_form_post = true
    c.http_post(Curl::PostField.file("@#{app}", app))
    if c.status == "200 OK"
      puts "\nFile Upload Status Code: #{c.status}"
      puts "Cloud App: sauce-storage:#{filename}\n"
      "sauce-storage:#{filename}"
    else
      puts "\n#{app}: File did not upload successfully.\nFile Upload Status Code: #{c.status}\nAborting...\n".red
      abort
    end
  end
end