
# Appium-Native-Crawler
Appium Native Crawler CLI - Features include: Screenshots, Performance, Accessibility Detection, Google  Translate, Applitools, Monkey Tester

# Appium Automated Exploratory Tester
Automated Exploratory Testing with Appium

Add google api key to settings.


#Why?
I built this because it was something I needed and thought should exist. We need more tools like this to help keep up with the rapid pace of development in the current marketplace.

#Will this work for every app?
Probably not but that is the challenge of building somethign that does. Will it work for most apps? I think so. If it doesn't work for your app, help make it work by contributing a pull request. :)

#Will this work on Windows?
I'm not sure but doubtful. I have only tested this on OSX and Linux environments. Please let me know if it doesn't work on Windows or help make it work by adding a pull request.

#How can you help?
* Look at the ToDo's! 
    * FWIW - You don't need to have Ruby knowelege to help with some of these.

#How does it work?
The crawler will run based on the CLI arguments and config file settings. The crawler detects all clickable and enabled elements on every view and iterates through them until something changes in the UI. Once it detects a change it then captures a screenshot, perforamnce data, and amongst other metadata. Based on your max runtime setting (-s or --seconds) it will run until this timesout or if a crash occurs. After a timeout or crash occurs a report is automatically generated.

#Requirements before using
* Android SDK Installed
* Appium Dependencies Installed
* Appium CLI Installed via npm. e.g ```npm install -g appium```
* Redis installed. e.g. ```brew install redis```

#Installation
* via rubygems.org ```gem install aaet```
    * or locally in repo via ```gem install pkg/aaet-*.gem```

#Examples
* Crawl portrait "default": (-s max runtime, -e emulator, -c config file, -d print debug output)
    * ```aaet crawler -s 300 -e EM1 -c path/to/configFile.txt -d true --trace``` 
    * See all options: ```aaet crawler --help```

* Crawl landscape: (-s max runtime, -e emulator, -c config file, -d print debug output, -o orientation)
    * ```aaet crawler -s 300 -e EM1 -c configs/wordpress.txt -d true -o landscape --trace ```
    * See all options: ```aaet crawler --help```
    * Note: Not all apps support landscape so crawler will fallback to portrait

* Replay: (-c config file, -s max runtime, -d print debug output, -e emulator)
    * ```aaet replay -c configs/wordpress.txt -s 300 -d true -e EM1 --trace```
    * See all options: ```aaet replay --help```

* Crawl Translate: (-s seconds, -e emulator, -c config file, -d debug, --reset Appium App Reset, -l languages, --translate Google Translate)
    * ```aaet crawler -s 120 -e EM1 -c configs/wordpress.txt -d true --reset false -l 'fr de' --translate true --trace```
    * See all options: ```aaet crawler --help```
    
* Monkey: (-c config file, -s max runtime, -d print debug output, -e emulator)
    * ```aaet monkey -c configs/wordpress.txt -s 300 -d true -e EM1 --trace```
    * See all options: ```aaet monkey --help```
    * Note: Not all apps are ideal for the monkey tester. Ideally, apps with lots of UI elements on each view work the best. If an app doesn't have many elements to interact with the monkey tester might appear to be doing nothing. This can be refactored of course and would love the help.

* Note: The --config/-c can reference any file path

#ToDo
* Implement iOS crawling
* Use YAML instead of TOML config files
* Implement Docker execution (Android).
    * Perhaps with Kubernetes
* Add specs/tests
* Refactor concurrent execution
* Refactor HTML Reports
* Implement Android Automator 2 
* Add more examples and documentation
* Modify to run on Windows (if it doesn't work)
* Rewrite this in javascript?


#Copywrite
(GPL-3.0)[Appium-Native-Crawler/LICENSE]
