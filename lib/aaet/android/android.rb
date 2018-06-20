#http://www.vogella.com/tutorials/AndroidCommandLine/article.html
require_relative '../common/locators'
require_relative '../common/redis'

module Aaet
  class Android < Aaet::Locators

    attr_accessor :uuid, :dir, :log, :exception_pattern, :redis

    def initialize settings
      generate_instance_variables nil, settings
      self.uuid = device[:uuid]
      self.dir = output_dir
      self.log = "exception-#{process}.log"
      self.exception_pattern = "FATAL EXCEPTION"
      self.redis = Aaet::Redis.new process
      remove_status_bar_and_notifications #show only the application in the window
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

    def dialog_button
      ({id: "android:id/button1"})
    end
    
    def remove_status_bar_and_notifications
      unless options_cloud
        #https://android.gadgethacks.com/how-to/hide-navigation-status-bars-your-galaxy-s8-for-even-more-screen-real-estate-no-root-needed-0177297/
        puts "\nRemoving Top Status Bar from Device...\n".yellow
        %x(adb -s #{uuid} shell 'settings put global policy_control immersive.status=*')
        %x(adb -s #{uuid} shell 'appops set android POST_NOTIFICATION ignore')
        sleep 1
      end
    end
    
    def reset_status_bar
      %x(adb -s #{uuid} shell settings put global policy_control null*) rescue nil #put status bar back...
    end
    
    def back_button
      puts "\nClicking Android Back Button!!!\n".red
      Appium::Common.back
    end

    def close_keyboard
      #http://appium.readthedocs.io/en/latest/en/commands/device/keys/hide-keyboard/
      if keyboard_open?
        puts "\nClosing keyboard!!!\n"
        #back_button
        driver.hide_keyboard rescue nil
        sleep 1
        if keyboard_open? #sometimes keyboard doesn't close so try again...
          #back_button
          driver.hide_keyboard rescue nil
        end
      end
    end

    def permission_dialog_displayed? act
      android_activities = ['.permission.ui.GrantPermissionsActivity', 'com.android.internal.app.ChooserActivity']
      android_activities.any?  { |a| a.include? act } rescue false
    end
    
    def close_permissions_dialog act
      if permission_dialog_displayed? act
        if act == "com.android.internal.app.ChooserActivity"
          back_button
        else
          puts "\nDetected Android Permissions/Chooser Dialog. Closing...\n".yellow
          fe({id: 'com.android.packageinstaller:id/permission_deny_button'}).click
        end
        sleep 1
      end
    end

    def is_textfield? locator
      "android.widget.EditText" == locator
    end

    def keyboard_open?
      #http://appium.readthedocs.io/en/latest/en/commands/device/keys/is-keyboard-shown/
      driver.is_keyboard_shown
      #%x(adb shell dumpsys input_method)[/mInputShown=\w+/i].split('=')[1] == 'true'
      #for iOS
      #driver.find_element(:xpath, '//UIAKeyboard').displayed?
    end

    #Force type keyboard when opened...
    def adb_type string
      %x(adb -s #{uuid} shell input text "#{string}\n")
    end

    def system_stats
      unless options_cloud
        x = %x(adb -s #{uuid} shell top -n 1 -d 1 | grep System).split(",")
        user = x.find { |x| x.include? "User" }.match(/User (.*)%/)[1].to_i rescue 0
        sys  = x.find { |x| x.include? "System" }.match(/System (.*)%/)[1].to_i rescue 0
        # iow  = x.find { |x| x.include? "IOW" }.match(/IOW (.*)%/)[1].to_i
        # irq  = x.find { |x| x.include? "IRQ" }.match(/IRQ (.*)%/)[1].to_i
        { app_mem: memory, app_cpu: cpu, user: user, sys: sys }
      end
    end

    def memory
      memory = (%x(adb -s #{uuid} shell dumpsys meminfo | grep #{caps_appPackage} | awk '{print $1}').strip.split.last.to_i * 0.001).round(2)
      puts "Memory: #{memory} MB"
      memory
    end

    def cpu
      cpu = %x(adb -s #{uuid} shell top -n 1 -d 1 | grep #{caps_appPackage} | awk '{print $3}').strip.chomp("%").to_i
      puts "Cpu: #{cpu}%"
      cpu
    end

    def logcat
      %x(adb -s #{uuid} logcat -c)
      @logcat_pid = spawn("adb -s #{uuid} logcat *:E -v long", :out=>"#{dir}/#{log}")
    end

    def process_running? pid
      begin
        Process.getpgid(pid)
        true
      rescue Errno::ESRCH
        false
      end
    end

    def kill_process process_name
      `ps -ef | grep #{process_name} | awk '{print $2}' | xargs kill >> /dev/null 2>&1`
    end

    def kill_emulator emulator
      system("adb -s #{emulator} emu kill")
    end

    def kill_everything
      pid = Process.getpgid(Process.pid)
      Signal.trap('TERM') { Process.kill('TERM', -pid); exit }
      Signal.trap('INT' ) { Process.kill('INT',  -pid); exit }
      reset_status_bar
      sleep 1
      Process.kill("HUP", appium_pid)
      Process.kill("SIGKILL", @logcat_pid)
      #kill_process "#{uuid} logcat -v threadtime"
      #kill_emulator uuid if options_emulator and options_kill_emulator
    end

    def start_log
      unless options_cloud
        logcat
        Process.fork do
          f = File.open("#{dir}/#{log}", "r")
          f.seek(0,IO::SEEK_END)
          while true
            break unless process_running? @logcat_pid
            select([f])
            if f.gets =~ /#{exception_pattern}/
              redis.app_crashed true
              puts "\n*******************  #{exception_pattern} DETECTED  *******************\nSHUTTING DOWN...\n".red
              sleep 3
              break
            end
          end
          f.close
          #binding.pry
          kill_everything
        end
      end
    end
  end
end