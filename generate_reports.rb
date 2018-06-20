require 'redic'
require 'json'
require 'awesome_print'
require 'tilt/haml'
require 'httparty'
require 'jsonpath'
require 'fileutils'
require 'pry'

class ReportBuilder

  attr_accessor :translate, :process, :options

  def initialize translate, process, options
    self.translate = translate
    self.options = options
    self.process = process
    @redis = Redic.new
  end

  def get_list list
    @redis.call("LRANGE", "#{list}-#{process}", 0, -1).map { |x| JSON.parse(x) }.uniq.flatten rescue []
  end

  def get_list_without_process list
    @redis.call("LRANGE", list, 0, -1).map { |x| JSON.parse(x) }.uniq.flatten rescue []
  end

  def found_activities
    @redis.call("LRANGE", "found_activities-#{process}", 0, -1)
  end

  def clicked_elements
    get_list("clicked").reverse
  end

  def app_crashed?
    eval(@redis.call("LRANGE", "crashed-#{process}", 0, -1)[0]) rescue false
  end

  def clicked_page_changed
    clicked = clicked_elements.find_all { |x| x["page_changed"] == true }
    if app_crashed?
      clicked << clicked_elements.last
      clicked.uniq
    else
      clicked.uniq
    end
  end

  def find_max_of_my_array(arr,type)
    arr.select{|x| x[:type] == type}.max_by{|x| x[:value_length]}
  end

  def max_cpu
    list = clicked_page_changed
    list.max_by { |x| x["performance"]["app_cpu"] || 0 }
  end

  def max_memory
    list = clicked_page_changed
    list.max_by { |x| x["performance"]["app_mem"] || 0 }
  end

  def page_texts
    get_list "page_text"
  end

  def screenshots dir
    Dir["#{dir}/*.png"]
  end

  def find_screenshot_path screenshot_array, md5
    screenshot_array.find { |x| x.include? md5 }
  end

  def parse_data dir
    ss = screenshots(dir)
    array = []
    e = clicked_page_changed
    e.each do |h|
      ss_path = find_screenshot_path(ss, h["page"])
      array << { screenshot: ss_path }.merge!(h)
    end
    array
  end

  def create_dir dir
    Dir.mkdir dir unless File.exists? dir
  end

  def create_graph(data, graph_opts = {})
    template_path = "#{File.dirname(__FILE__)}/template_google_api_format.haml"
    default_graph_settings = { miniValue: 0, maxValue: 2000, width: 1500, height: 900 }

    template = Tilt::HamlTemplate.new(template_path)
    template.render(Object.new,
                    title: graph_opts[:title],
                    header1: graph_opts[:header1],
                    data_file_path: data,
                    graph_settings: graph_opts[:graph_settings] || default_graph_settings)
  end

  def export_as_google_api_format(data)
    google_api_data_format = google_api_format
    data.each do |hash|
      puts hash
      a_google_api_data_format = {
          c: [
              { v: "Date(#{hash[:time]})" },
              { v: hash["app_mem"] },
              { v: "<img src='#{hash[:screenshot]}' alt='' width='240' height='400'>" },
              { v: hash["app_cpu"] },
              { v: "<img src='#{hash[:screenshot]}' alt='' width='240' height='400'>" },
              { v: hash["user"] },
              { v: "<img src='#{hash[:screenshot]}' alt='' width='240' height='400'>" },
              { v: hash["sys"] },
              { v: "<img src='#{hash[:screenshot]}' alt='' width='240' height='400'>" },
          ],
      }
      google_api_data_format[:rows].push(a_google_api_data_format)
    end
    JSON.generate google_api_data_format
  end

  def google_api_format
    {
        cols: [
            { label: 'time',      type: 'datetime' },
            { label: 'app_mem',   type: 'number' },
            { role: 'tooltip',    type: 'string', p: { html: true } },
            { label: 'app_cpu',   type: 'number' },
            { role: 'tooltip',    type: 'string', p: { html: true } },
            { label: 'user',      type: 'number' },
            { role: 'tooltip',    type: 'string', p: { html: true } },
            { label: 'sys',       type: 'number' },
            { role: 'tooltip',    type: 'string', p: { html: true } },
        ],
        rows: [
        ],
    }
  end

  def convert_time string
    require 'date'
    DateTime.parse(string).strftime('%H:%M:%S')
  end

  def convert_time_to_unix timestamp
    (Time.parse(timestamp).to_f * 1000).ceil
  end

  def generate_performance_html_report fileaname, report_data
    create_dir "#{Dir.pwd}/reports"
    report_dir = "#{Dir.pwd}/reports/#{fileaname}"
    create_dir report_dir

    maxcpu = report_data[:max_values][:max_cpu]
    maxmem = report_data[:max_values][:max_mem]

    app_data = report_data[:app_info]
    device_data = report_data[:device_info]

    header = app_data[:package_name]
    title = "| v: #{app_data[:version]} | maxCpu: #{maxcpu} | maxMem: #{maxmem} | appSize: #{app_data[:app_size]}mb | os: #{device_data[:os]} | sdk:#{device_data[:sdk]} |"
    data = report_data[:data].map { |x| { time: convert_time_to_unix(x["time"]), screenshot: x[:screenshot]}.merge(x["performance"]) unless x["performance"].nil? }.compact
    output = export_as_google_api_format data

    open("#{report_dir}/perf-#{fileaname}.txt", 'w') { |f| f << output }
    graph_opts = { title: title, header1: header}
    report = create_graph("#{report_dir}/perf-#{fileaname}.txt", graph_opts)
    open("#{report_dir}/perf-#{fileaname}.html", 'w') { |f| f << report }
  end

  def detect array
    begin
      array.map { |string| { string: string, detected: get_locale(string) } }
    rescue
      nil
    end
  end

  def get_locale string
    res = google_api string
    lang = jpath(res["data"], "language").join
    conf = jpath(res["data"], "confidence").join
    { locale: lang, confidence: conf }
  end

  def google_api string, key = ENV["GOOGLE_API_KEY"]
    if ENV["GOOGLE_API_KEY"].nil?
      puts "\nNeed GOOGLE_API_KEY Environment Variable API Key...\n".red
      return
    else
      HTTParty.get("https://www.googleapis.com/language/translate/v2/detect", query: { q: string, key: key })
    end
  end

  def jpath(hash, key)
    JsonPath.on(hash, "$..#{key}")
  end

  def collect_bad_strings strings = page_texts, correct_locale
    text_array = strings.map { |x| x["text"] }.flatten.uniq
    text_array.reject! { |e| e.to_s.empty? }
    detected_locales = detect(text_array)
    detected_locales.collect do |t|
      strings.find_all { |x| x["text"].include? t[:string] }.map { |x| { activity: x["activity"], page: x["page"], translated: t } if t[:detected][:locale] != correct_locale }.compact
    end.flatten.group_by { |h| h[:page] }.each { |_,v| v.map! { |h| h[:translated][:string] } }
  end

  def generate_translations_report filename, title, array
    create_dir "#{Dir.pwd}/reports"
    report_dir = "#{Dir.pwd}/reports/#{filename}"
    create_dir report_dir

    gallery_css = <<-CSS
    img {
      padding: 0px;
      margin: 0px 24px 24px 0px;
      border: 3px solid #ccc;
      border-radius: 2px;
      box-shadow: 3px 3px 5px #ccc;
    }
    CSS

    File.open("#{report_dir}/strings-#{filename}.html", 'w') do |f|

      layout = <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{title}</title>
          <style type="text/css" media="screen">
            #{ gallery_css }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>#{title}</h1>
          </div>
        </body>
        </html>
      HTML

      f << layout

      array.each do |data|
        f << "<p>Detected Strings: #{data[:strings].join(" , ")}</p>"
        f << "<img src=\"#{data[:screenshot]}\">"
        f << "<P class=\"breakhere\">"
      end
    end
  end

  def generate_screenshots_report filename, title
    create_dir "#{Dir.pwd}/reports"
    report_dir = "#{Dir.pwd}/reports/#{filename}"
    create_dir report_dir

    gallery_css = <<-CSS
    div.gallery {
      margin: 5px;
      border: 1px solid #ccc;
      float: left;
      width: 180px;
    }

    div.gallery:hover {
      border: 1px solid #777;
    }

    div.gallery img {
      width: 100%;
      height: auto;
    }
    
    div.desc {
      padding: 15px;
      text-align: center;
    }
    CSS

    screenshots = Dir["#{options[:output_dir]}/*.png"]

    File.open("#{report_dir}/screenshots-#{filename}.html", 'w') do |f|

      layout = <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{title}</title>
          <style>
            #{ gallery_css }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>#{title}</h1>
          </div>
        </body>
        </html>
      HTML

      f << layout

      screenshots.each do |image|
        f << "<div class='gallery'>"
        f << "<a target='_blank' href='#{image}'>"
        f << "<img src='#{image}' width='300' height='200'>"
        f << "</a>"
        #"<div class='desc'>Add a description of the image here</div>"
        f << "</div>"
      end
    end
  end

  def create_base_report filename
    create_dir "#{Dir.pwd}/reports"
    report_dir = "#{Dir.pwd}/reports/#{filename}"
    create_dir report_dir
    report_links = Dir["#{report_dir}/*"].map { |r| { name: File.basename(r).split("-")[0].upcase, report: r } }

    File.open("#{report_dir}/#{filename}.html", 'w') do |f|

      layout = <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{options[:config][:caps][:caps][:appPackage]}</title>
          <style type="text/css" media="screen">
              table, th, td {
                border: 1px solid black;
                border-collapse: collapse;
              }
              th, td {
                  padding: 5px;
              }
              th {
                  text-align: left;
              }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>#{options[:config][:caps][:caps][:appPackage]}</h1>
          </div>
          <p>App Version: #{options[:app_and_device_data][:app_version]}</p>
          <p>App Size: #{options[:app_and_device_data][:app_size]} MB</p>

        </body>
        </html>
      HTML

      f << layout

      f << generate_table(f, "Report Links", "Report", "Link", report_links)
      f << "<p></p>"
      f << "<p></p>"
      f << generate_table(f, "AAET Arguments", "Option", "Value", options[:options])
      f << generate_table(f, "Capabilities Used", "Capability", "Value", options[:config][:caps][:caps])
      f << generate_table(f, "Device Attributes", "Attribute", "Value", options[:app_and_device_data][:device])
      f << "<p></p>"
      f << "<p></p>"

      activities = options[:app_and_device_data][:activities].map { |a| { :"#{a}"=> found_activities.include?(a).to_s } }.reduce({}, :merge)
      f << generate_table(f, "App Activities", "Activity", "Found", activities)

      if options[:options][:applitools]
        all_tests = options[:config][:applitools][0].keys
        all_tests.delete(:do_not_upload)

        #results_array = get_list("applitools_results")
        results_array = get_list_without_process("applitools_results")

        url = results_array[0]["url"]
        results_hash = results_array.map { |t| { :"#{t["test"]}"=> t["passed"] } }.reduce({}, :merge)
        missing_tests = all_tests - results_hash.keys
        missing_tests.each { |t| results_hash.merge!({:"#{t}" => "N/A"}) }
        f << generate_table(f, "Applitools Tests", "Test", "Passed", results_hash, url)
      end
    end
  end

  def generate_table report_block, table_name, column1, column2, data_array, *url
    report_block << "<table style='display: inline-block;'>"
    if url[0]
      report_block << "<caption><a href='#{url[0]}'>#{table_name}</a></caption>"
    else
      report_block << "<caption>#{table_name}</caption>"
    end
    report_block << "<tr>"
    report_block << "<th>#{column1}</th>"
    report_block << "<th>#{column2}</th>"
    report_block << "</tr>"
    data_array.each do |key, value|
      if key.is_a? Hash
        report_block << "<tr>"
        report_block << "<td>#{key.values[0]}</td>"
        report_block << "<td><a href='#{key.values[-1]}'>#{File.basename(key.values[-1])}</a></td>"
        report_block << "</tr>"
      else
        report_block << "<tr>"
        report_block << "<td>#{key}</td>"
        report_block << "<td>#{value}</td>"
        report_block << "</tr>"
      end
    end
    report_block << "</table>"
  end

  def generate_reports
    #output dir
    dir = options[:output_dir]

    #app info
    app_data = options[:app_and_device_data]
    package_name = app_data[:app_package]
    app_version = app_data[:app_version]
    app_size = app_data[:app_size]
    language = options[:config][:caps][:caps][:language]
    orientation = options[:config][:caps][:caps][:orientation]
    activities = options[:app_and_device_data][:activities]

    #device info
    device_date = options[:app_and_device_data][:device]
    platform = device_date[:platform]
    uuid = device_date[:uuid]
    manufacturer = device_date[:manufacturer]
    model = device_date[:model]
    os = device_date[:os]
    sdk = device_date[:sdk]

    #Max performance values
    #unless options[:options][:cloud]
      maxmem = max_memory["performance"]["app_mem"] rescue 0
      maxcpu = max_cpu["performance"]["app_cpu"] rescue 0
    #end

    #did the app crash?
    crashed = app_crashed?

    app_info    = { package_name: package_name, version: app_version, language: language, orientation: orientation, app_size: app_size }
    device_info = { platform: platform, manufacturer: manufacturer, model: model, uuid: uuid, os: os, sdk: sdk }
    max_values  = { max_mem: maxmem, max_cpu: maxcpu }
    data        = parse_data(dir)
    report      = { crashed: crashed, app_info: app_info, device_info: device_info, max_values: max_values, data: data }

    if crashed
      filename = "#{options[:run_time]}-#{uuid}-#{process}-#{package_name}.crashed"
    else
      filename = "#{options[:run_time]}-#{uuid}-#{process}-#{package_name}"
    end

    report_dir = "#{Dir.pwd}/reports/#{filename}"
    create_dir report_dir

    if options[:options][:translate]
      bad = collect_bad_strings(language)
      screenshot_array = screenshots(dir)
      grouped = bad.map { |x| { screenshot: find_screenshot_path(screenshot_array, x[0]), strings: x[1] } }
      generate_translations_report(filename, "Translations", grouped)
    end

    #generate perforance report.
    unless options[:options][:cloud]
      generate_performance_html_report filename, report

      #copy logcat to report dir
      logcat = dir + "/exception-#{options[:process]}.log"
      FileUtils.cp logcat, "#{Dir.pwd}/reports/#{filename}"
      FileUtils.rm_f logcat if File.exists? logcat

      #copy appium log to report dir
      appium_log = options[:output_dir_base] + "/appium-#{options[:process]}.log"
      FileUtils.cp appium_log, "#{Dir.pwd}/reports/#{filename}"
      FileUtils.rm_f appium_log if File.exists? appium_log
    end

    #create yml file from AAET options for reporting
    File.write("#{Dir.pwd}/reports/#{filename}/aaet_options-#{options[:process]}.yml", options.to_yaml)

    #create screenshots report
    device = options[:config][:caps][:caps][:udid]
    generate_screenshots_report filename, "#{device} Screenshots"

    create_base_report filename

    #save run data to runs dir.
    report_dir = "#{Dir.pwd}/runs"
    create_dir report_dir
    open("#{report_dir}/#{filename}.json", 'w') { |f| f << report.merge!({options: options, activities: activities}) }
  end
end

#ReportBuilder.new(false).generate_reports