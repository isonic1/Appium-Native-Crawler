# Appium Automated Exploratory Tester - Automated Automation

### Appium Native Crawler CLI 

* Features include: 
    * Collect Screenshots 
    * Performance Data Collection
    * Run in Landscape and Portrait
    * Accessibility Detection
    * Google Translate App Strings
    * Automated Test with [Applitools Eyes](https://www.applitools.com)
    * Monkey Tester Mode
    * Replaying an exploratory test crawl

<img src="https://www.dropbox.com/s/xrhl67ru1z2dh08/crawler-report-trimmed.gif?raw=1" width="800">

# Why?
I built this because it was something I needed and thought should exist. We need more tools like this to help keep up with the rapid pace of development in the current marketplace. I also got tired or writing and refactoring tests for a constantly changing application. So I decided to try to automate to automation by building automated exploratory testing.

# Will this work for every app?
Probably not but that is the challenge of building somethign that does. Will it work for most apps? I think so. If it doesn't work for your app, help make it work by contributing a pull request. :)

# Will this work on Windows?
I have only tested this on OSX and Linux environments but it will need some refactoring for Windows. Please help make it work by adding a pull request. :)

# How can you help?
* Look at the ToDo's! 
    * FWIW - You don't need to have Ruby knowledge to help with some of these.

# Requirements before using
* Ruby 2.2 or greater (I have not tested this with Ruby 2.5 but I assume it will work)
    * I highly recommend installing RVM or RBENV.
    * Install Ruby devkit or GCC C++ Dependencies (e.g. on osx: xcode-select --install). Basically, just make sure you can install the json gem. e.g. ```gem install json```
        * If you get an error installing the above json gem, Google on how to fix it on your machine before proceeding.
* Android SDK Installed. See [here](https://www.androidcentral.com/installing-android-sdk-windows-mac-and-linux-tutorial)
* All Appium Dependencies Installed. See [here](https://github.com/isonic1/appium-workshop/blob/master/Appium%20Mac%20Installation%20Instructions.md) or goto [here](http://appium.io/docs/en/about-appium/getting-started/)
* Appium CLI installed via node npm. e.g ```npm install -g appium```
* Redis server installed and started. e.g. ```brew install redis```
    * Make sure you set the Redis server to always start on bootup.
    
# Gem Installation
* via rubygems.org ```gem install aaet```
    * or locally from the cloned repo via ```gem install Appium-Native-Crawler/pkg/aaet-*.gem```

# Before you start
* Install all the requirements specified
* Run the example project in the examples folder
    * cd Appium-Native-Crawler/examples
    * Open the app-debug.txt in an editor or VIM to see example of usage. Don't change anything!
    * Pick an emulator avd to use. Run ```emulator -list-avds```
        * If you've installed the Android SDK correctly (in it's in your path) this should output the AVD's on your machine. If don't have any of the latter (AVD's), open the Android AVD Manager and create one.
    * Run CLI: ```aaet crawler -s 300 -e <avd name from step above> -c app-debug.txt --debug --trace``` 
        * Or use a real device: ```aaet crawler -s 300 -u <uuid of connected device> -c app-debug.txt --debug --trace``` 
        * If all goes well this will run the crawler for 5 minutes (300 seconds) or until a crash occurs.
    * Open the HTML report generated in the reports folder with FIREFOX. Chrome, Safari won't display the performace report. I could use help fixing this so please add a PR if you know how to resolve it!
    * The report gathers it's data from the output screenshots directory and json report and in the "runs" directory. The replay feature uses this json file to rerun which ever test you want. You can also store this metadata in a db/graphite for historical lookup and benchmarking.
* If you want to try with the Wordpress App. Go [here](https://github.com/wordpress-mobile/WordPress-Android#oauth2-authentication) and follow the instructions to create a developer account to get a unique app_id and app_secret to compile the app locally.
    * You can then use the example wordpress.txt config file to crawl the app.

# How does it work?
* The crawler will run based on the CLI arguments and config file settings. The crawler detects all clickable and enabled elements on every view and iterates through them until something changes in the UI. Once it detects a change it then captures a screenshot, perforamnce data, and amongst other metadata. Based on your max runtime setting (-s or --seconds) it will run until this times out or a crash occurs. After a timeout or crash occurs a report is automatically generated in the reports folder.

# Example Usage
* Crawl portrait "default": (-s (max runtime in seconds), -e (avd name or "em1 em2 em3"), -c (path to config file), --debug (print debug output))
    * ```aaet crawler -s 300 -e EM1 -c path/to/configFile.txt --debug --trace``` 
    * See all options: ```aaet crawler --help```
    * Note: The Crawler automatically starts the emulator(s) if not already started.

* Crawl landscape: (-s (max runtime in seconds), -e (avd name), -c (path to config file), --debug (print debug output), -o (orientation))
    * ```aaet crawler -s 300 -e EM1 -c configs/wordpress.txt --debug -o landscape --trace ```
    * See all options: ```aaet crawler --help```
    * Note: Not all apps support landscape (e.g. app-debug.apk) so crawler will fallback to portrait
    * Note: The Crawler automatically starts the emulator(s) if not already started.

* Replay: (-c (path to config file), -s (max runtime in seconds or until last crawl steps are finished), --debug (print debug output))
    * ```aaet replay -c configs/wordpress.txt -s 300 --debug --trace```
    * See all options: ```aaet replay --help```
    * Select the past crawl you want to replay by the choice list.
        * Replay crawler will then load last used config settings and command line arguments unless you override them.
    * Note: The Crawler automatically starts the emulator or connects to device last used in selection.
    
* Monkey: (-c (path to config file), -s (max runtime in seconds), --debug (print debug output), -e (avd name))
    * ```aaet monkey -c configs/wordpress.txt -s 300 --debug -e EM1 --trace```
    * See all options: ```aaet monkey --help```
    * Note: Not all apps are ideal for the monkey tester. Ideally, apps with lots of UI elements on each view work the best. If an app doesn't have many elements to interact with the monkey tester might appear to be doing nothing. This can be refactored of course and would love the help. Submit a PR!
    * Note: The Crawler automatically starts the emulator(s) if not already started.

* Crawl & Translate: (-s (max runtime in seconds), -e (avd name), -c (path to config file), --debug (print debug output), --reset (Appium App Reset default: false), -l (languages array "en fr de"), --translate (Google Translate String))
    * ```aaet crawler -s 120 -e EM1 -c configs/wordpress.txt --debug --reset -l 'fr de' --translate --trace```
    * See all options: ```aaet crawler --help```
    * Note: The Crawler automatically starts the emulator(s) if not already started.
    * Note: Your app must support multiple languages for this to work.
    * Note: The app will iterate through each language at the given time in seconds. e.g. -s 120 and -l "fr de", it will crawl and collect metadata in each language for 2 minutes each or until a crash occurs.
    * Note: Do not put a comma between language code, just a space. e.g. "en de fr"
    * Note: Need Google API Key. Go [here](https://cloud.google.com/translate/docs/quickstart) to create dev account and get key. Set a GOOGLE_API_KEY environment variable or place key in config file.
    
* Crawl & Applitools: (-s (max runtime in seconds), -e (avd name), -c (path to config file), --debug (print debug output), --reset (Appium App Reset default: false), --applitools (run applitools tests defined in config file))
    * ```aaet crawler -s 120 -e EM1 -c configs/wordpress.txt --debug --reset --applitools --trace```
    * See all options: ```aaet crawler --help```
    * Note: The Crawler automatically starts the emulator(s) if not already started.
    * Note: The Crawler will upload to applitools based on the tests you define in the config TOML file. Make sure you add your API Key in the config file or have a APPLITOOLS_API_KEY environment variable set.

* Crawl in Parallel: (-s (max runtime in seconds), -e (avd name or array "en fr de"), -c (path to config file), --debug (print debug output))
    * ```aaet crawler -s 120 -e "Nexus1 MyEmulator" -c configs/wordpress.txt --debug --trace```
    * ```aaet crawler -s 120 -u "UUID1 UUID2" -c configs/wordpress.txt --debug --trace```
    * See all options: ```aaet crawler --help```
    * Note: Do not put a comma between AVD's or UUID's, just a space. e.g. "AVD1 AVD2" or "UUID1 UUID2"
    * Note: The Crawler automatically starts the emulator(s) if not already started.
    * Note: You can force both orientations by passing ```--bothOrientations true``` This will only work when > 1 devices are running.
       
* Crawl on the Cloud: (-s (max runtime in seconds), -c (path to config file), --debug (print debug output), --cloud (run on cloud service defined in config file))
    * ```aaet crawler -s 120 -c configs/wordpress.txt --debug --cloud true --trace```
    * See all options: ```aaet crawler --help```
    * Make sure you have the cloud settings and cloud caps configured in the config files.
    * Note: The performance and logcat data is not captured on cloud runs, only screenshots. You can get this additional metadata from the cloud provider.
    * Note: You can force both orientations by passing ```--bothOrientations true``` This will only work when > 1 devices are configured in cloud caps file.
    
* Note: The --config/-c can reference any file path. So if you have multple apps or versions you can configure your folder/file structure accordingly.
* Debugging: Passing --debug will print out a lot of debugging output. One such debugging output are the instance variables set which are derived dynamically based on the config and command line arguments/options and then passed into each class. See [here](https://github.com/isonic1/Appium-Native-Crawler/blob/master/run.rb#L46-L63) for example.
* Definitely look at the --help menu for each option (crawler, replay, monkey). This will tell you all the available arguments you can use. Also, look at the code for further reference!

# Using your app!
* Can your application be automated by Appium? Make sure you can actually run automation on your app with Appium before proceeding. Some apps have security settings to block automation or screenshot captures.
    * Go [here](https://github.com/appium/sample-code/tree/master/sample-code/examples) and run one of the android example apps. 
    * Then configure your android app to run on Appium using one of these examples to see if it works.
    * If the above works for your app, continue to next steps.
* Create a new config file for your app. e.g myAwesomeApp.txt
* Cut and paste the contents from the app-debug.txt into this file.
* Modify the capabilities to match your apps capabilities. You can add more capabilities specific to your app if you need to, though the crawler is not configured to handle anything other than the ones you see. Open an issue or better yet create a PR to handle these if needed. 
    * Note: This will not work with UiAutomator2 capability currently. That is in the works to implement.
* Just make sure the format of the TOML/config file is the same as the examples. Otherwise, you might get some funky errors due to unexpected parsing issues. I plan to switch to YAML config files which will be easier to lint.
* Also look at the wordpress.txt config file for further reference example.
* Use uiautomatorviewer, Appium Inspector, the Appium Desktop App or whichever hierarchy viewer tool you want to get the locator values you need from your app and place into the config file for the backLocators, multiClickLocators, loginPage, doNotClick, applitools fields.
* See [toml-rb](https://github.com/emancu/toml-rb) TOML gem for examples of different available field formats

# Reports Generated
<img src="https://www.dropbox.com/s/9yq7qt9loeki9z9/crawler-report.gif?raw=1" width="600">

# Contributing
* Bug reports and pull requests are welcome on GitHub at https://github.com/isonic1/Appium-Native-Crawler/issues. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.
* Pull Request are highly welcomed and encouraged! See TODO's for list of things to be done.

# TODO's
* Implement iOS crawling
* Use YAML instead of TOML config files
* Implement Docker execution (Android Only).
    * Perhaps with Kubernetes
* Remove or refactor activity parser
* DRY the code more
* Add specs/tests
* Capture additional performance data. e.g. battery usage
* Implement gesture logic
* Generate accessibility report from json output
* Add wiki documentation
    * Add more examples and documentation
* Refactor concurrent execution
* Refactor/Improve HTML Reports
    * generate_reports.rb needs to be cleaned up.
* Implement UiAutomator2
    * Some of the locator parsing logic will need to be updated and how the crawler obtains certain variables about the environment.
* Modify to run on Windows
    * This actually wouldn't take too much effort other than time.

# Copywrite
(GPL-3.0)[Appium-Native-Crawler/LICENSE]
