require 'eyes_selenium'

module Aaet
  class ApplitoolEyes

    attr_accessor :eyes, :applitools_settings, :uuid

    def initialize settings
      puts "\nRun Applitools Tests: true\n".green
      self.eyes = Applitools::Selenium::Eyes.new
      self.applitools_settings = settings[:config][:applitools][0]
      eyes.api_key = applitools_settings[:key]
      eyes.save_failed_tests = settings[:options][:updateBaseline]
      batch_info = Applitools::BatchInfo.new(caps[:appPackage]) #app name, locale, orientation
      batch_info.id = Digest::MD5.hexdigest(settings[:run_time]).scan(/\d/).join('')
      eyes.batch = batch_info
      eyes.match_level = :strict
      self.uuid = settings[:config][:caps][:udid]
    end

    def eyes_open app_name, test_name
      eyes.open(driver: driver, app_name: app_name, test_name: test_name)
    end

    def upload_to_applitools app_name, test_name, tag
      eyes_open app_name, test_name
      eyes.check_window tag
    end

    def close_eyes
      results = eyes.close(false)
      eyes.abort_if_not_closed
      results
    end

    def tests
      applitools_settings.delete(:key)
      applitools_settings.map { |test| { name: test[0].to_s }.merge!(test[1]) }
    end
  end
end