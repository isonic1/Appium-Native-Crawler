require_relative 'redis'
require_relative 'applitools'
require_relative '../common/locators'
require_relative '../android/parser'
require_relative '../android/android'
require_relative '../ios/ios'
require_relative '../ios/parser'

module Aaet
  class Common < Aaet::Locators

    attr_accessor :applitools, :tests, :count, :redis, :execute, :parser, :wait_for_element, :dir, :uuid

    def initialize settings
      generate_instance_variables nil, settings

      if options_applitools
        self.applitools = Aaet::ApplitoolEyes.new settings
        self.tests = applitools.tests
        print_debug "\nApplitools Tests:".green
        ap tests if options_debug
        print_debug "\n"
      end

      self.count = "%03d" % 1
      self.redis = Aaet::Redis.new process

      if caps_platform == "android"
        self.execute = Aaet::Android.new settings
        self.parser = Aaet::AndroidParser.new
      elsif caps_platform == "ios"
        self.execute = Aaet::Ios.new settings #placeholder for iOS
        self.parser = Aaet::IosParser.new
      end

      self.wait_for_element = 10
      self.dir = output_dir

      if options_cloud
        self.uuid = "#{cloud_service}-#{caps_deviceName.gsub(" ","_")}"
      else
        self.uuid = device[:uuid]
      end

      @window_size = driver.manage.window.size.to_a
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

    def print_debug string
      puts string if options_debug
    end

    def login_page?
      print_debug "#{uuid}: Checking if on Login page..."
      login_hash = config[:loginPage] rescue {}
      if login_hash.any?
        login if (activity == login_hash[0][:activity])
      end
    end

    def login
      puts "#{uuid}: ON THE LOGIN PAGE. I WILL LOGIN NOW!!!"
      config_loginPage[0][:steps].each do |step|
        driver.wait(config_loginPage[0][:maxWaitBetweenSteps]) { fe({:"#{step[1]}"=>step[2]}) }
        print_debug "action: #{step[0]}, locator: :#{step[1]}=>#{step[2]}, text: #{step[3]}"
        self.send(step[0], fe({:"#{step[1]}"=>step[2]}), step[3])
        execute.close_keyboard if execute.keyboard_open?
        sleep 5
      end
      wait_for_home_screen
      #set_screen_boudaries
    end

    def wait_for_home_screen
      Appium::Common.wait_true(wait_for_element) { activity == config[:homeActivity][:activity] }
    end

    def store_clicked_element body
      print_debug "\n#{uuid}: Storing clicked element: #{body}\n"
      redis.update_list "clicked", body
    end

    def clicked_elements
      redis.get_list "clicked"
    end

    def start_log
      execute.start_log
    end

    def stop_log
      execute.stop_log
    end

    def outside_screen_boundaries?(screen_size, location)
      if location[0] < 0 or location[1] < 0
        true
      elsif location[0] > screen_size[0] or location[1] > screen_size[1]
        true
      else
        false
      end
    end

    def uploaded_to_applitools test
      #redis.update_list "applitools", test
      redis.update_applitools "applitools", test
    end

    def has_uploaded? test
      #redis.list_includes_value "applitools", test
      redis.list_includes_applitools_value "applitools", test
    end

    def applitools_results results, test
      hash = { test: test, failed: results.failed?, passed: results.passed?, new: results.new?, url: results.url }
      #redis.update_list "applitools_results", hash
      redis.update_applitools "applitools_results", hash
    end

    def is_test?
      print_debug "#{uuid}: Checking for Applitool test..."
      do_not_upload = tests.find_all { |test| test[:name] == "do_not_upload" }[0].select { |loc| loc if loc != :name } rescue []
      current_activity_tests = tests.find_all { |test| test[:activity] == activity } rescue []
      if displayed?(do_not_upload) #skip if do_not_upload locator displayed...
        false
      else
        if current_activity_tests.empty?
          false
        else
          current_activity_tests.each do |test|
            #store screenshot name in redis if pushed to applitools so not to get duplicates.
            locator = Hash[*test.to_a[2]]
            unless fe(locator).nil? or get_text(test[:text]).nil?
              test_name = "#{test[:name]}-#{device_resolution}"
              unless has_uploaded? test_name
                print_debug "\n#{uuid}: Uploading test '#{test_name}' to Applitools!\n".yellow
                applitools.upload_to_applitools caps_appPackage, test_name, test[:text]
                results = applitools.close_eyes
                applitools_results results, test_name
                uploaded_to_applitools test_name
                #TODO: create a method to shutdown after test count matches redis test count...
                #redis.hincr("applicount", "count")
              end
            end
          end
        end
      end
    end

    def take_screenshot?
      md5 = md5_page_source
      unless screenshot_exists? md5
        is_test? if options_applitools
        print_debug "#{uuid}: Taking a screenshot..."
        screenshot "#{dir}/#{count}_#{md5}.png"
        count.next!
      end
    end

    def screenshot_exists? md5
      files = Dir.entries(dir).select { |x| x.include? ".png" } rescue []
      files.any? { |x| x.include? md5 } unless files.empty?
    end

    def relaunch_app
      print_debug "#{uuid}: Launching App!!!"
      `curl -s -X POST #{caps_url}/session/#{driver.session_id}/appium/app/launch`
      #@new_page = []
      sleep 5
    end

    def relaunch_app?
      print_debug "#{uuid}: Checking to Relaunch app..."
      act = activity
      unless redis.activities.any? { |a| a.include? act }
        if execute.permission_dialog_displayed? act
          execute.close_permissions_dialog act
          sleep 2
        else
          execute.back_button
          unless redis.activities.any? { |a| a.include? activity }
            relaunch_app
          end
        end
      end
    end

    def page_changed? element
      changed = md5_page_source != element[:page]
      print_debug "\n#{uuid} The page has changed!!! Restarting...\n".red if changed
      changed
    end

    def md5_page_source
      print_debug "MD5'ing the Page Source..."
      #Can also maybe use get_page_class to distinguish between pages...
      Digest::MD5.hexdigest(get_source)
    end

    def string
      chars = Lorem.characters(rand(1..100))
      sentence = Faker::Hipster.sentence(1)
      words = (Faker::Hipster.words(rand(1..10))).shuffle.join(" ")
      url = Faker::Internet.url
      mac = Faker::Internet.mac_address
      #[chars, words, url, mac].sample
      #Right now just sending hipster text but maybe randomize this in the future...
      sentence
    end

    def close_keyboard
      execute.close_keyboard if execute.keyboard_open?
    end

    def type_if_keyboard_is_open
      if execute.keyboard_open?
        print_debug "#{uuid}: Keyboard is open. I will type now..."
        type "#{string}\n"
        close_keyboard
        string
      end
    end

    def dialog_displayed?
      displayed? execute.dialog_button
    end

    def accept_dialog
      #maybe override this with appium capability to auto accept dialogs. Undecieded about it, though...
      click execute.dialog_button if dialog_displayed?
    end

    def reset_dialog_count
      redis.hset("dialog","count", 0)
    end

    def increment_dialog_count
      redis.hincr("dialog","count")
    end

    def dialog_count
      redis.hget("dialog", "count").to_i
    end

    def remove_clicked_element
      redis.lpop "clicked"
    end

    def click_dialog?
      if dialog_displayed?
        if dialog_count >= 3
          print_debug "#{uuid}: Clicking OK on Dialog!!!"
          accept_dialog
          reset_dialog_count
        else
          print_debug "#{uuid}: Skipping Dialog click..."
          increment_dialog_count
          return
        end
      else
        reset_dialog_count
      end
    end

    def weighted_actions
      #TODO: implement these later... [multi_touch, shake, forcepress, longpress]
      actions = ["random_tap", "swipe_right", "swipe_left", "pull_to_refresh", "buttons", "back", "swipe_down", "swipe_up"]
      weights = [45, 15, 15, 10, 5, 5, 3, 2]
      ps = weights.map { |w| (Float w) / weights.reduce(:+) }
      weighted_actions = actions.zip(ps).to_h
      wrs = -> (freq) { freq.max_by { |_, weight| rand ** (1.0 / weight) }.first }
      action = wrs[weighted_actions]
      print_debug "#{uuid}: Performing Action: #{action}".yellow
      action
    end

    def collect_chaos_performance body
      redis.update_list "chaos", body
    end

    def monkey
      login_page?
      relaunch_app?
      #binding.pry
      action = weighted_actions
      if action == "buttons"
        b = buttons
        unless b.empty?
          print_debug "#{uuid}: Clicking random button...".yellow
          begin b.sample.click rescue nil end
        end
      elsif action == "back"
        execute.back_button unless activity == homeActivity[:activity]
      else
        self.send(action)
      end
      sleep 0.3
      #TODO: collect_chaos_performance({time: Time.now, performance: Thread.new { execute.system_stats }.value})
    end

    #TODO: Return boolean if replay step is displayed...
    #use this to debug replay values
    def check_replay_element_values step
      element_values = []
      [:bounds, :id, :accessibilty_label].each do |key|
        next if step[key].nil?
        if [:id, :accessibilty_label].include? key
          element = fe({id: step[key]})
        else
          element = fe({xpath: "//#{step[:class]}[@bounds='#{step[:bounds]}']"})
        end
        next if element.nil?
        location = element.location
        size = element.size
        element_values << {
            locator_used: key,
            element: element,
            location: location.to_h,
            step_location: step[:location],
            center: element_center(location, size),
            step_center: step[:center],
            step_id: step[:id],
            step_accessibilty_label: step[:accessibilty_label],
            step_bounds: step[:bounds]
        }
      end
      element_values
    end

    def replay
      last_run_steps.each do |step|
        #take_screenshot #not yet implemented logic yet to store screenshots in new location.
        relaunch_app?
        login_page?

        locator = step[:accessibilty_label] || step[:id]

        if locator.nil?
          wait(wait_for_element) { fe({xpath: "//#{step[:class]}[@bounds='#{step[:bounds]}']"}) } rescue nil #will wait if element exists...
          element = fe({xpath: "//#{step[:class]}[@bounds='#{step[:bounds]}']"})
        else
          wait(wait_for_element) { fe({id: locator}) } rescue nil #will wait if element exists...
          element = fe({id: locator})
        end

        print_debug "\n#{uuid}: Last Run Step: #{step}\n"
        print_debug ""

        #binding.pry
        #check_replay_element_values step

        if step[:id] == "force-tap-back"
          execute.back_button
        else
          element.click
        end

        if execute.keyboard_open? and step[:typed]
          print_debug "\n#{uuid}: Typying Last Run Text: #{step[:typed]}\n"
          type "#{step[:typed]}\n"
          close_keyboard
        else
          type_if_keyboard_is_open
        end

        sleep 0.5
        #step[:performance] = Thread.new { execute.system_stats }.value #To compare peformance from last test run...
      end
      sleep 5 #wait for a crash to happen
    end

    def new_activity current_activity
      if activity == current_activity
        nil
      else
        activity
      end
    end

    def update_element_list act, elements
      if redis.activity_exists? act
        old_elements = redis.get_list(act)
        new_elements = elements
        diff = diff_actvity_elements(old_elements, new_elements) rescue []
        unless diff.empty?
          redis.del_list activity
          select_elements = new_elements.select { |e| diff.map { |x| x[:id] }.include? e[:id] }
          redis.update_list activity, (old_elements + select_elements)
        end
        redis.update_activity_count act
      end
    end

    def diff_actvity_elements old_page, new_page
      a = old_page.map { |x| { id: x[:id], label: x[:accessibilty_label] } }.uniq
      b = new_page.map { |x| { id: x[:id], label: x[:accessibilty_label] } }.uniq
     ( b - a )
    end
    
    def dont_click
      config_doNotClick.map { |h| h.map { |k,v| v.values } }.flatten rescue []
    end

    def store_page_text body
      print_debug "\n#{uuid}: Storing Page Text: #{body}\n"
      redis.update_list "page_text", body
    end

    def store_accessibility_labels body
      print_debug "\n#{uuid}: Storing Accessibility Labels: #{body}\n"
      redis.update_list "accessibility_labels", body
    end

    def fix_orientation rotation
      #TODO: Since parser.page tells the orientation we can do something with it....
      if config[:caps][:caps][:orientation] == "PORTRAIT"
        orientation = 0
      else
        orientation = 1
      end
      set_orientation = config[:caps][:caps][:orientation].downcase.to_sym
      driver.rotate(set_orientation) if orientation != rotation
    end

    def get_elements page_objects = parser.page, act
      print_debug "\n#{uuid}: Getting page elements..."
      md5 = md5_page_source
      a = act
      elements = []
      dialog = dialog_displayed?
      rotation =  page_objects[0][:rotation].to_i
      page_objects.each do |o|
        next unless (o[:enabled] and o[:clickable])
        o[:dialog] = false if o[:dialog].nil?
        elements << { activity: a, page: md5, dialog_displayed: dialog, rotation: rotation }.merge!(o)
      end
      elements = elements.uniq
      update_element_list a, elements
      page_text = page_objects.map { |t| t[:text] }.compact.reject { |e| e.empty? }
      store_page_text([{activity: a, page: md5, text: page_text}])
      accessibility_labels = page_objects.map { |l| l[:accessibilty_label] }.compact.reject { |e| e.empty? }
      store_accessibility_labels([{activity: a, page: md5, text: accessibility_labels}])

      objects = []
      clicked_list = clicked_elements
      elements.each { |e| been_clicked?(clicked_list, e); objects << e.merge!({click_count: @click_count, clicked_before: @has_clicked}) }
      objects.shuffle.sort_by { |x| x[:click_count] }
    end

    def get_element_attributes object
      locator = object[:accessibilty_label] || object[:id] #use accessibility label first and then id if available
      if locator.nil?
        element = fe({xpath: "//#{object[:class]}[@bounds='#{object[:bounds]}']"})
      else
        element = fe({id: locator})
      end
      return if element.nil?

      location = element.location rescue nil
      return if location.nil? or outside_screen_boundaries?(@window_size.to_a, location.to_a)
      displayed = element.displayed? rescue false
      return unless displayed
      size = element.size

      {
          location: location.to_h,
          displayed: displayed,
          window_size: @window_size,
          center: element_center(location, size),
          element: element,
          size: size.to_h
      }.merge!(object)
    end

    def back_locator_displayed?
      locators = config_backLocators.map { |h| h.map { |k,v| v } }.flatten rescue []
      false if locators.empty?
      locators.shuffle.each do |locator|
        if displayed? locator
          print_debug "\n#{uuid}: Tapping Back Locator: #{locator}\n".yellow
          @back_locator = locator
          return true
        else
          return false
        end
      end
    end

    def clicked_before?(e)
      #center may change if scrolling is enabled. cant use accessibility label because that can change...
      clicked = clicked_elements.find { |c|
        c[:id] == e[:id] and c[:size] == e[:size] and c[:center] == e[:center] and c[:activity] == e[:activity] and c[:class] == e[:class]
      }
      @click_count = clicked[:click_count] rescue 0
      clicked.any? rescue false
    end

    def been_clicked?(clicked_list, e)
      #add a weighted selection on how many clicks have occured...
      clicked = clicked_list.find do |x|
        x[:index] == e[:index] and
        x[:class] == e[:class] and
        x[:package] == e[:package] and
        x[:checkable] == e[:checkable] and
        #x[:checked] == e[:checked] and
        x[:clickable] == e[:clickable] and
        x[:focusable] == e[:focusable] and
        x[:focused] == e[:focused] and
        x[:scrollable] == e[:scrollable] and
        x[:long_clickable] == e[:long_clickable] and
        #x[:selected] == e[:selected] and
        x[:bounds] == e[:bounds] and
        x[:id] == e[:id] and
        x[:instance] == e[:instance] and
        x[:clickable] == e[:clickable] and
        x[:enabled] == e[:enabled] and
        x[:activity] == e[:activity]
      end
      @click_count = clicked[:click_count] rescue 0
      begin
        clicked.any?
        @has_clicked = true
      rescue
        @has_clicked = false
        false
      end
    end

    def crawler
      print_debug "\n#{uuid}: Starting!!!\n".green

      take_screenshot?
      relaunch_app?
      login_page?

      current_activity = activity
      print_debug "#{uuid}: Current Activity: #{current_activity}"

      #binding.pry

      objects = get_elements current_activity
      if objects.empty?
        if current_activity != homeActivity[:activity]
          execute.back_button
        else
          relaunch_app
        end
        return
      end

      catch(:stop) do
        print_debug "#{uuid}: Objects Count: #{objects.count}\n"
        objects.each_with_index do |o,oi|
          print_debug "\n#{uuid}: INDEX: #{oi}\nOBJECT: #{o}\n"

          e = get_element_attributes(o)
          next if e.nil? or dont_click.include? e[:id]

          print_debug "\n#{uuid}: Using Element: #{e}\n"
          e[:page_changed] = false

          if e[:click_count] >= settings[:click_count]
            if oi == objects.size - 1
              if back_locator_displayed?
                e = get_element_attributes(@back_locator) #reset element to config_backLocators attributes...
                been_clicked?(clicked_elements, e)
                e.merge!({click_count: @click_count, activity: o[:activity], page: o[:page]}) #merge object attributes into e.
              else
                #this logic will need to change for iOS unless we can create a method to simulate a back button like android has...
                e = { click_count: 0, class: nil, text: nil, location: nil, center: nil, element: nil, id: "force-tap-back" }
                e.merge!({activity: o[:activity], page: o[:page]}) #merge object attributes into e.
              end
            else
              print_debug "\n#{uuid}: Skipping Element: #{e}".yellow
              print_debug "#{uuid}: I've tapped this Locator #{@click_count} times before...\n".yellow
              next
            end
          end

          e[:clicked] = true #store clicked element in case app crashes when clicked.

          #TODO: Set rules hash on click counts by locator class. e.g. textfield, button etc...
          if e[:class] == "android.widget.EditText" #only click textfields once
            e[:click_count] = 3
          else
            e[:click_count] = e[:click_count] + 1
          end

          if e[:dialog]
            e[:click_count] = 0
          end

          e[:time] = Time.now
          store_clicked_element e

          if e[:id] == "force-tap-back"
            execute.back_button; sleep 0.2
            if e[:page] == md5_page_source
              #at a last resort relaunch the app...
              print_debug "\n#{uuid}: Stuck on the same view/page. Getting outta here...\n".red
              relaunch_app
            end
          else
            click e[:element]
          end

          sleep 0.2
          e[:typed] = type_if_keyboard_is_open

          if page_changed? e
            remove_clicked_element
            e[:page_changed] = true
            e[:performance] = Thread.new { execute.system_stats }.value
            e[:new_activity] = new_activity(e[:activity])
            e[:new_page] = md5_page_source
            store_clicked_element e
            throw :stop
          end
        end
      end
    end
  end
end