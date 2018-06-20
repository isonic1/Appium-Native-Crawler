module Aaet
  class AndroidParser

    class Appium::Android::AndroidElements

      def reset
        @result   = []
      end

      def start_element(name, attrs = [], driver = driver)
        return if filter && !name.downcase.include?(filter)

        attributes = {}

        do_not_include = ["android:id/content", "android:id/navigationBarBackground", "android:id/content",
                          "android:id/parentPanel", "android:id/topPanel", "android:id/title_template",
                          "android:id/contentPanel", "android:id/scrollView", "android:id/buttonPanel"]

        attrs.each do |key, value|

          #do not include this values
          next if do_not_include.include? value

          if key.include? "-"
            key = key.gsub("-","_")
          end

          if key == "resource_id"
            key = "id"
          elsif key == "content_desc"
            key = "accessibilty_label"
          end

          if ["android:id/button2", "android:id/button1"].include? value
            attributes["dialog"] = true
          end

          if value.empty?
            value = nil
          end

          if key == "bounds"
            bounds_array = value.scan(/\d*/).reject { |c| c.empty? }.map { |v| v = v.to_i }
            bounds_array_value = bounds_array.each_slice((bounds_array.size/2.0).round).to_a
            attributes["bounds_array"] = bounds_array_value
          end

          attributes[key] = value
        end

        eval_attrs = ["checkable", "checked", "clickable", "enabled", "focusable", "focused",
                      "scrollable", "long_clickable", "password", "selected", "instance", "index"]

        @result << attributes.reduce({}) do |memo, (k, v)|
          if eval_attrs.include? k.to_s
            v = eval(v) rescue false
          end
          memo.merge({ k.to_sym => v})
        end
      end
    end

    def page(opts = {})
      class_name = opts.is_a?(Hash) ? opts.fetch(:class, nil) : opts
      results = get_android_inspect class_name
      results.map { |h| results.delete(h) if h.values.uniq == [nil] }
      results
    end

    def print_page
      page.each do |result|
        puts "\n#{result}\n"
      end
    end
  end
end