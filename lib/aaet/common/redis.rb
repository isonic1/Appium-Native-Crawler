module Aaet
  class Redis

    attr_accessor :redis, :process

    def initialize process
      self.redis = Redic.new
      self.process = process
      update_list("crashed", false)
    end

    def del_list list
      redis.call "DEL", "#{list}-#{process}" rescue nil
    end

    def update_applitools list, body
      redis.call "LPUSH", list, JSON.generate(body)
    end

    def update_list list, body
      redis.call "LPUSH", "#{list}-#{process}", JSON.generate(body)
    end

    def activity_exists? act
      activities.any? { |a| a.include? act }
    end

    def remove_activity activity
      redis.call "LREM", "activities", -1, activity
    end

    def activities
      redis.call("LRANGE", "activities", 0, -1)
    end

    def found_activities
      redis.call("LRANGE", "found_activities-#{process}", 0, -1)
    end

    def found_activity_exists? act
      found_activities.any? { |a| a.include? act }
    end

    def add_found_activity act
      redis.call "LPUSH", "found_activities-#{process}", act
    end

    def update_activity_count act
      unless found_activity_exists? act
        checkmark = "\u2713"
        puts ""
        puts "\nNew Activity Found! #{checkmark}".green
        add_found_activity act
        remaining = (activities.count - found_activities.count)
        puts "Remaining Activities: #{remaining}\n"
        puts ""
      end
    end

    def get_list list
      redis_list = redis.call("LRANGE", "#{list}-#{process}", 0, -1).map { |x| JSON.parse(x) }.uniq.flatten rescue []
      unless redis_list.empty?
        redis_list = symbolize(redis_list)
      end
      redis_list
    end

    def symbolize(obj)
      return obj.reduce({}) do |memo, (k, v)|
        memo.tap { |m| m[k.to_sym] = symbolize(v) }
      end if obj.is_a? Hash

      return obj.reduce([]) do |memo, v|
        memo << symbolize(v); memo
      end if obj.is_a? Array

      obj
    end

    def list_includes_value list, value
      redis.call("LRANGE", "#{list}-#{process}", 0, -1).any? { |a| a.include? value }
    end

    def list_includes_applitools_value list, value
      redis.call("LRANGE", list, 0, -1).any? { |a| a.include? value }
    end

    def app_crashed boolean
      redis.call "LPUSH", "crashed-#{process}", boolean
    end

    def lpop list
      redis.call "LPOP", "#{list}-#{process}"
    end

    def hincr(key, field)
      redis.call("HINCRBY", "#{key}-#{process}", field, 1)
    end

    def hset(key, field, value)
      redis.call("HSET", "#{key}-#{process}", field, value)
    end

    def hget(key, field)
      redis.call("HGET", "#{key}-#{process}", field)
    end
  end
end