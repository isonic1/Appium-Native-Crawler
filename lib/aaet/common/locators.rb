module Aaet
  class Locators

    def activity
      count = 0
      begin
        JSON.parse(`curl -s #{caps_url}/session/#{driver.session_id}/appium/device/current_activity`)['value']
      rescue
        count+=1
        return if count > 3
        retry
      end
    end

    def get_center(element)
      location   = element.location
      location_x = location.x.to_f
      location_y = location.y.to_f
      size = element.size
      size_width  = size.width.to_f
      size_height = size.height.to_f
      x = location_x + (size_width / 2.0)
      y = location_y + (size_height / 2.0)
      {x: x, y: y}
    end
    
    def element_center(location, size)
      location_x = location.x.to_f
      location_y = location.y.to_f
      size_width  = size.width.to_f
      size_height = size.height.to_f
      x = location_x + (size_width / 2.0)
      y = location_y + (size_height / 2.0)
      {x: x, y: y}
    end

    def long_press element
      center = get_center(element)
      center.merge!(fingers: 1, duration: 550)
      action = Appium::TouchAction.new.long_press center
      action.release.perform
    end

    def press coords
      coords.merge!(fingers: 1, duration: 550)
      action = Appium::TouchAction.new.long_press coords
      begin action.release.perform rescue nil end
    end

    def tap args = {}
      begin
        Appium::TouchAction.new.tap(args).release.perform
      rescue
        nil
      end
    end

    def tap2 coords
      begin
        Appium::TouchAction.new.tap(coords).release.perform
      rescue
        nil
      end
    end

    def random_tap
      x = rand(0..@window_size[0])
      y = rand(0..@window_size[1])
      puts "\nRandom Tap Location: { x: #{x}, y: #{y} }\n".yellow
      tap({:x=>x, :y=>y})
    end

    def pull_to_refresh
      size = get_window_size
      start_x = size[:width] / 2
      start_y = size[:height] / 2
      end_x = size[:width] / 2
      end_y = size[:height] - 100
      Appium::TouchAction.new.press({x:start_x,y:start_y}).wait(200).move_to({x:end_x,y:end_y}).release.perform
    end

    def get_window_size
      window_size.to_h
    end

    def swipe_down
      size = @window_size
      start_x = size[0] / 2
      start_y = size[1] / 2
      end_x = size[0] / 2
      end_y = size[1] - 200
      Appium::TouchAction.new.press({x:start_x,y:start_y}).wait(200).move_to({x:end_x,y:end_y}).release.perform
    end

    def swipe_up
      size = @window_size
      start_x = size[0] / 2
      start_y = size[1] / 2
      end_x = size[0] / 2
      end_y = 100
      Appium::TouchAction.new.press({x:start_x,y:start_y}).wait(200).move_to({x:end_x,y:end_y}).release.perform
    end

    def swipe_left
      size = @window_size
      start_x = (size[0] - 60).to_f
      start_y = (size[1] / 2).to_f
      end_x = 60.to_f
      end_y = (size[1] / 2).to_f
      Appium::TouchAction.new.press({x:start_x,y:start_y}).wait(200).move_to({x:end_x,y:end_y}).release.perform
      #swipe({start_x:63,end_y:326})
    end

    def swipe_right
      size = @window_size
      start_x = 60.to_f
      start_y = (size[1] / 2).to_f
      end_x = (size[0] - 60).to_f
      end_y = (size[1] / 2).to_f
      Appium::TouchAction.new.press({x:start_x,y:start_y}).wait(200).move_to({x:end_x,y:end_y}).release.perform
    end

    def fe locator
      begin
        find_element(locator)
      rescue
        nil
      end
    end

    def fa locator
      begin
        find_elements(locator)
      rescue
        []
      end
    end

    def get_text string
      begin
        text string
      rescue
        nil
      end
    end

    def displayed? locator
      begin
        fe(locator).displayed?
      rescue
        false
      end
    end

    def click locator, *optional
      begin
        locator.click
      rescue
        nil
      end
    end

    def type string
      begin
        driver.keyboard.send_keys string
      rescue
        nil
      end
    end

    ###For Login Method
    def enter locator, string
      begin
        locator.send_keys string
      rescue
        nil
      end
    end
  end
end