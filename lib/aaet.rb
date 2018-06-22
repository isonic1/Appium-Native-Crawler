require "version"
require 'appium_lib'
require 'awesome_print'
require 'colorize'
require 'faker'
require 'redic'
require 'nokogiri'
require 'pp'

require_relative 'aaet/common/common_methods'

include Faker

module Aaet
  class Runner

    attr_accessor :common

    def initialize settings
      self.common = Aaet::Common.new(settings)
    end

    def monitor_log_start
      common.start_log
    end

    def crawler
      common.crawler
    end

    def replay
      common.replay
    end

    def monkey
      common.monkey
    end

    def current_activity
      common.get_activity
    end
  end
end