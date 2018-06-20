#https://developer.android.com/studio/run/emulator-commandline.html
#https://devmaze.wordpress.com/2011/12/12/starting-and-stopping-android-emulators/
#-tcpdump /path/dumpfile.cap

require 'apktools/apkxml'
require 'json'

class AndroidSetup

  attr_accessor :cloud, :caps, :cloud_service

  def initialize settings
    self.cloud = settings[:options][:cloud]
    self.caps = settings[:config][:caps][:caps]
    self.cloud_service = settings[:config][:cloud][:service] || nil
  end

  ###Emulator methods
  def available_emulators
    %x($ANDROID_HOME/tools/emulator -list-avds).split("\n")
  end

  def check_emulator avd
    emulators = available_emulators
    if avd.nil? or !emulators.include? avd
      puts "\nINVALID OR NIL EMULATOR: #{avd}\nAvailable Emulators: #{emulators}\n".red
      puts "Example: -e #{emulators.sample}\nAborting...".red
      abort
    else
      true
    end
  end

  def emulators_booted?
    %x(adb -s #{uuid} shell getprop sys.boot_completed).strip == "1"
  end

  def start_avd
    unless emulator_running?
      if check_emulator avd
        kill_emulator uuid
        @pid = spawn("$ANDROID_HOME/tools/emulator -avd #{avd} -port #{port} &", :out=>"/dev/null")
        #%x(adb -s #{uuid} wait-for-device)
        start = Time.now
        until emulators_booted?
          sleep 1
          if Time.now - start > 30
            puts "\nEmulator #{uuid} failed to boot within 30 seconds. Aborting run....".red
            puts "Check Emulator: #{uuid}\n".red
            abort
          end
        end
      end
    end
  end

  def kill_emulator emulator
    system("adb -s #{emulator} emu kill >> /dev/null 2>&1")
  end

  def running_emulators
    (`adb devices`).scan(/\n(.*)\t/).flatten.select { |d| d.include? "emulator" }
  end

  def emulator_running?
    running_emulators.include? uuid
  end

  def kill_all_emulators
    emulators = running_emulators
    emulators.delete uuid
    if emulators.any?
      puts "\nKilling all emulators...\n"
      emulators.each { |emulator| kill_emulator emulator }
      sleep 5
    end
  end

  ###End Emulator methods

  def devices
    (`adb devices`).scan(/\n(.*)\t/).flatten
  end

  def devices_connected?
    devices.any?
  end

  def check_for_devices
    unless devices_connected?
      puts "\nNo Devices Connected or Authorized!!!\nMake sure at least one device (emulator/simulator) is connected!\n".red
      abort
    end
  end

  def check_uuid uuid
    if devices_connected?
      if devices.include? uuid
        true
      else
        puts "\nINVALID OR NIL UUID: #{avd}\nAvailable Devices: #{devices}\n".red
        puts "Example: -u #{devices.sample}\nAborting...".red
        abort
      end
    else
      false
    end
  end

  def get_device_data uuid
    specs = {
        os: "ro.build.version.release",
        manufacturer: "ro.product.manufacturer",
        model: "ro.product.model",
        sdk: "ro.build.version.sdk"
    }
    hash = {}
    specs.each do |key, spec|
      value = `adb -s #{uuid} shell getprop "#{spec}"`.strip
      hash.merge!({key=> "#{value}"})
    end
    hash.merge!({platform: "android", uuid: uuid, resolution: nil, process: Parallel.worker_number})
  end

  def app_size
    (`wc -c <#{caps[:app]}`).strip
  end

  def get_app_data
    data = ApkXml.new caps[:app]
    data.parse_xml("AndroidManifest.xml", false, true)
    manifest = data.xml_elements[0].attributes
    package = manifest.find {|x| x.name == "package" }["value"].strip
    version = manifest.find {|x| x.name == "versionName" }["value"].strip
    { package: package, version: version }
  end

  def app_and_device_data uuid
    app_data = get_app_data
    if cloud
      device_data = {
          uuid: "#{cloud_service}-#{uuid}",
          deviceName: "#{caps[:deviceName].gsub(' ','_')}",
          os: caps[:platformVersion],
          manufacturer: "unknown",
          model: "unknown",
          sdk: "unknown",
          resolution: nil,
          process: Parallel.worker_number
      }
    else
      device_data = get_device_data(uuid).merge!(deviceName: "#{caps[:deviceName].gsub(' ','_')}")
    end
    {
        app_package: app_data[:package],
        app_version: app_data[:version],
        app_size: app_size,
        device: device_data
    }
  end
end