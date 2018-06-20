#iOS Placeholder
module Aaet
  class Ios

    # include Appium::Ios
    # include Appium::Common
    # include Appium::Device

    def keyboard_open?
      begin
        #driver.driver.manage.timeouts.implicit_wait = 0.1
        fe({xpath: '//UIAKeyboard'}).displayed?
      rescue Selenium::WebDriver::Error::NoSuchElementError
        false
      end
    end
  end
end