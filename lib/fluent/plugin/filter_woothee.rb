class Fluent::WootheeFilter < Fluent::Filter
  Fluent::Plugin.register_filter('woothee', self)
  Fluent::Plugin.register_filter('woothee_fast_crawler_filter', self)

  config_param :fast_crawler_filter_mode, :bool, :default => false

  config_param :key_name, :string

  config_param :filter_categories, :default => [] do |val|
    val.split(',').map(&:to_sym)
  end
  config_param :drop_categories, :default => [] do |val|
    val.split(',').map(&:to_sym)
  end
  attr_accessor :mode

  config_param :merge_agent_info, :bool, :default => false
  config_param :out_key_name, :string, :default => 'agent_name'
  config_param :out_key_category, :string, :default => 'agent_category'
  config_param :out_key_os, :string, :default => 'agent_os'
  config_param :out_key_os_version, :string, :default => nil # supress output
  config_param :out_key_version, :string, :default => nil # supress output
  config_param :out_key_vendor, :string, :default => nil # supress output

  def initialize
    super
    require 'woothee'
  end

  def configure(conf)
    super

    if conf['type'] == 'woothee_fast_crawler_filter' or @fast_crawler_filter_mode
      @fast_crawler_filter_mode = true

      if @filter_categories.size > 0 or @drop_categories.size > 0 or @merge_agent_info
        raise Fluent::ConfigError, "fast_crawler_filter cannot be specified with filter/drop/merge options"
      end

      return
    end

    if @filter_categories.size > 0 and @drop_categories.size > 0
      raise Fluent::ConfigError, "both of 'filter' and 'drop' categories specified"
    elsif @filter_categories.size > 0
      unless @filter_categories.reduce(true){|r,i| r and Woothee::CATEGORY_LIST.include?(i)}
        raise Fluent::ConfigError, "filter_categories has invalid category name"
      end
      @mode = :filter
    elsif @drop_categories.size > 0
      unless @drop_categories.reduce(true){|r,i| r and Woothee::CATEGORY_LIST.include?(i)}
        raise Fluent::ConfigError, "drop_categories has invalid category name"
      end
      @mode = :drop
    else
      @mode = :through
    end

    if @mode == :through and not @merge_agent_info
      raise Fluent::ConfigError, "configured not to do nothing (not to do either filter/drop nor addition of parser result)"
    end
  end

  def fast_crawler_filter_stream(tag, es)
    new_es = Fluent::MultiEventStream.new

    es.each do |time,record|
      unless Woothee.is_crawler(record[@key_name] || '')
        new_es.add(time, record.dup)
      end
    end
    new_es
  end

  def normal_filter_stream(tag, es)
    new_es = Fluent::MultiEventStream.new

    es.each do |time,record|
      parsed = Woothee.parse(record[@key_name] || '')

      category = parsed[Woothee::ATTRIBUTE_CATEGORY]
      next if @mode == :filter and not @filter_categories.include?(category)
      next if @mode == :drop and @drop_categories.include?(category)

      if @merge_agent_info
        record = record.merge({
            @out_key_name => parsed[Woothee::ATTRIBUTE_NAME],
            @out_key_category => parsed[Woothee::ATTRIBUTE_CATEGORY].to_s,
            @out_key_os => parsed[Woothee::ATTRIBUTE_OS]
          })
        record[@out_key_os_version] = parsed[Woothee::ATTRIBUTE_OS_VERSION] if @out_key_os_version
        record[@out_key_version] = parsed[Woothee::ATTRIBUTE_VERSION] if @out_key_version
        record[@out_key_vendor] = parsed[Woothee::ATTRIBUTE_VENDOR] if @out_key_vendor
      end
      new_es.add(time, record.dup)
    end
    new_es
  end

  def filter_stream(tag, es)
    if @fast_crawler_filter_mode
      fast_crawler_filter_stream(tag, es)
    else
      normal_filter_stream(tag, es)
    end
  end
end if defined?(Fluent::Filter)
