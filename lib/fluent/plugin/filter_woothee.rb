require 'fluent/plugin/filter'
require 'woothee'

class Fluent::Plugin::WootheeFilter < Fluent::Plugin::Filter
  Fluent::Plugin.register_filter('woothee', self)
  Fluent::Plugin.register_filter('woothee_fast_crawler_filter', self)

  config_param :fast_crawler_filter_mode, :bool, default: false

  config_param :key_name, :string

  config_param :filter_categories, :array, value_type: :string, default: []
  config_param :drop_categories, :array, value_type: :string, default: []

  attr_accessor :mode

  config_param :merge_agent_info, :bool, default: false
  config_param :out_key_name,       :string, default: 'agent_name'
  config_param :out_key_category,   :string, default: 'agent_category'
  config_param :out_key_os,         :string, default: 'agent_os'
  config_param :out_key_os_version, :string, default: nil # supress output in default
  config_param :out_key_version,    :string, default: nil # supress output in default
  config_param :out_key_vendor,     :string, default: nil # supress output in default

  def configure(conf)
    specified_type_name = conf['@type']

    super

    @filter_categories = @filter_categories.map(&:to_sym)
    @drop_categories = @drop_categories.map(&:to_sym)

    if specified_type_name == 'woothee_fast_crawler_filter' || @fast_crawler_filter_mode
      @fast_crawler_filter_mode = true

      if @filter_categories.size > 0 || @drop_categories.size > 0 || @merge_agent_info
        raise Fluent::ConfigError, "fast_crawler_filter cannot be specified with filter/drop/merge options"
      end

      define_singleton_method(:filter, method(:filter_fast_crawler))
      return
    end

    if @filter_categories.size > 0 && @drop_categories.size > 0
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

    if @mode == :through && ! @merge_agent_info
      raise Fluent::ConfigError, "configured not to do nothing (not to do either filter/drop nor addition of parser result)"
    end

    define_singleton_method(:filter, method(:filter_standard))
  end

  def filter(tag, time, record)
    # dynamically overwritten by #configure
    if @fast_crawler_filter_mode
      filter_fast_crawler(tag, time, record)
    else
      filter_standard(tag, time, record)
    end
  end

  def filter_fast_crawler(tag, time, record)
    if Woothee.is_crawler(record[@key_name] || '')
      nil
    else
      record
    end
  end

  def filter_standard(tag, time, record)
    parsed = Woothee.parse(record[@key_name] || '')

    category = parsed[Woothee::ATTRIBUTE_CATEGORY]
    return nil if @mode == :filter && !@filter_categories.include?(category)
    return nil if @mode == :drop && @drop_categories.include?(category)

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
    record
  end
end
