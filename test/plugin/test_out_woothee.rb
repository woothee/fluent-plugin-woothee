require 'helper'
require 'fluent/test/driver/output'

class Fluent::WootheeOutputTest < Test::Unit::TestCase
  # fast crawler filter
  CONFIG0 = %[
type woothee_fast_crawler_filter
key_name useragent
tag filtered
]

  # through & merge
  CONFIG1 = %[
type woothee
key_name agent
remove_prefix test
add_prefix merged
merge_agent_info yes
]

  # filter & merge
  CONFIG2 = %[
type woothee
key_name agent
filter_categories pc,smartphone,mobilephone,appliance
remove_prefix test
add_prefix merged
merge_agent_info yes
out_key_name ua_name
out_key_category ua_category
out_key_os ua_os
out_key_os_version ua_os_version
out_key_version ua_version
out_key_vendor ua_vendor
]

  # drop & non-merge
  CONFIG3 = %[
type woothee
key_name user_agent
drop_categories crawler,misc
tag selected
]

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf=CONFIG1)
    Fluent::Test::Driver::Output.new(Fluent::WootheeOutput).configure(conf)
  end

  def test_configure
    # fast_crawler_filter
    d = create_driver CONFIG0
    assert_equal true, d.instance.fast_crawler_filter_mode
    assert_equal 'useragent', d.instance.key_name
    assert_equal 'filtered', d.instance.tag

    # through & merge
    d = create_driver CONFIG1
    assert_equal false, d.instance.fast_crawler_filter_mode
    assert_equal 'agent', d.instance.key_name
    assert_equal 'test', d.instance.remove_prefix
    assert_equal 'merged', d.instance.add_prefix

    assert_equal 0, d.instance.filter_categories.size
    assert_equal 0, d.instance.drop_categories.size
    assert_equal :through, d.instance.mode

    assert_equal true, d.instance.merge_agent_info
    assert_equal 'agent_name', d.instance.out_key_name
    assert_equal 'agent_category', d.instance.out_key_category
    assert_equal 'agent_os', d.instance.out_key_os
    assert_nil d.instance.out_key_version
    assert_nil d.instance.out_key_vendor

    # filter & merge
    d = create_driver CONFIG2
    assert_equal false, d.instance.fast_crawler_filter_mode
    assert_equal 'agent', d.instance.key_name
    assert_equal 'test', d.instance.remove_prefix
    assert_equal 'merged', d.instance.add_prefix

    assert_equal 4, d.instance.filter_categories.size
    assert_equal [:pc,:smartphone,:mobilephone,:appliance], d.instance.filter_categories
    assert_equal 0, d.instance.drop_categories.size
    assert_equal :filter, d.instance.mode

    assert_equal true, d.instance.merge_agent_info
    assert_equal 'ua_name', d.instance.out_key_name
    assert_equal 'ua_category', d.instance.out_key_category
    assert_equal 'ua_os', d.instance.out_key_os
    assert_equal 'ua_os_version', d.instance.out_key_os_version
    assert_equal 'ua_version', d.instance.out_key_version
    assert_equal 'ua_vendor', d.instance.out_key_vendor

    # drop & non-merge
    d = create_driver CONFIG3
    assert_equal false, d.instance.fast_crawler_filter_mode
    assert_equal 'user_agent', d.instance.key_name
    assert_equal 'selected', d.instance.tag

    assert_equal 0, d.instance.filter_categories.size
    assert_equal 2, d.instance.drop_categories.size
    assert_equal [:crawler,:misc], d.instance.drop_categories
    assert_equal :drop, d.instance.mode

    assert_equal false, d.instance.merge_agent_info
  end

  def test_tag_mangle
    p = create_driver(CONFIG0).instance
    assert_equal 'filtered', p.tag_mangle('data')
    assert_equal 'filtered', p.tag_mangle('test.data')
    assert_equal 'filtered', p.tag_mangle('test.test.data')
    assert_equal 'filtered', p.tag_mangle('test')

    p = create_driver(CONFIG1).instance
    assert_equal 'merged.data', p.tag_mangle('data')
    assert_equal 'merged.data', p.tag_mangle('test.data')
    assert_equal 'merged.test.data', p.tag_mangle('test.test.data')
    assert_equal 'merged', p.tag_mangle('test')

    p = create_driver(CONFIG3).instance
    assert_equal 'selected', p.tag_mangle('data')
    assert_equal 'selected', p.tag_mangle('test.data')
    assert_equal 'selected', p.tag_mangle('test.test.data')
    assert_equal 'selected', p.tag_mangle('test')
  end

  def test_emit_fast_crawler_filter
    d = create_driver CONFIG0
    time = Time.parse('2012-07-20 16:19:00').to_i
    d.run(default_tag: 'test') do
      d.feed(time, {'useragent' => 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)', 'value' => 1})
      d.feed(time, {'useragent' => 'Mozilla/5.0 (compatible; Yahoo! Slurp; http://help.yahoo.com/help/us/ysearch/slurp)', 'value' => 2})
      d.feed(time, {'useragent' => 'Mozilla/5.0 (iPad; U; CPU OS 4_3_2 like Mac OS X; ja-jp) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8H7 Safari/6533.18.5', 'value' => 3})
      d.feed(time, {'useragent' => 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0)', 'value' => 4})
      d.feed(time, {'useragent' => 'Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)', 'value' => 5})
      d.feed(time, {'useragent' => 'Mozilla/5.0 (compatible; Rakutenbot/1.0; +http://dynamic.rakuten.co.jp/bot.html)', 'value' => 6})
      d.feed(time, {'useragent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_4; ja-jp) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.2 Safari/525.20.1', 'value' => 7})
      d.feed(time, {'useragent' => 'Yeti/1.0 (NHN Corp.; http://help.naver.com/robots/)', 'value' => 8})
    end

    events = d.events
    assert_equal 4, events.size

    assert_equal 'filtered', events[0][0]
    assert_equal time, events[0][1]
    assert_equal 'Mozilla/5.0 (iPad; U; CPU OS 4_3_2 like Mac OS X; ja-jp) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8H7 Safari/6533.18.5', events[0][2]['useragent']
    assert_equal 3, events[0][2]['value']
    assert_equal 2, events[0][2].keys.size

    assert_equal 4, events[1][2]['value']
    assert_equal 6, events[2][2]['value']
    assert_equal 7, events[3][2]['value']
  end

#   # through & merge
  def test_emit_through
    d = create_driver(CONFIG1)
    time = Time.parse('2012-07-20 16:40:30').to_i
    d.run(default_tag: 'test.message') do
      d.feed(time, {'value' => 0, 'agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'})
      d.feed(time, {'value' => 1, 'agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'})
      d.feed(time, {'value' => 2, 'agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'})
      d.feed(time, {'value' => 3, 'agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'})
      d.feed(time, {'value' => 4, 'agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'})
      d.feed(time, {'value' => 5, 'agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'})
      d.feed(time, {'value' => 6, 'agent' => 'Mozilla/5.0 (compatible; Google Desktop/5.9.1005.12335; http://desktop.google.com/)'})
      d.feed(time, {'value' => 7, 'agent' => 'msnbot/1.1 (+http://search.msn.com/msnbot.htm)'})
    end

    events = d.events
    assert_equal 8, events.size
    assert_equal 'merged.message', events[0][0]
    assert_equal time, events[0][1]

    # 'agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'
    m = events[0][2]
    assert_equal 0, m['value']
    assert_equal 'Internet Explorer', m['agent_name']
    assert_equal 'pc', m['agent_category']
    assert_equal 'Windows 8', m['agent_os']
    assert_equal 5, m.keys.size

    # 'agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = events[1][2]
    assert_equal 1, m['value']
    assert_equal 'Firefox', m['agent_name']
    assert_equal 'pc', m['agent_category']
    assert_equal 'Windows Vista', m['agent_os']

    # 'agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = events[2][2]
    assert_equal 2, m['value']
    assert_equal 'Firefox', m['agent_name']
    assert_equal 'pc', m['agent_category']
    assert_equal 'Linux', m['agent_os']

    # 'agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'
    m = events[3][2]
    assert_equal 3, m['value']
    assert_equal 'Safari', m['agent_name']
    assert_equal 'smartphone', m['agent_category']
    assert_equal 'Android', m['agent_os']

    # 'agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'
    m = events[4][2]
    assert_equal 4, m['value']
    assert_equal 'docomo', m['agent_name']
    assert_equal 'mobilephone', m['agent_category']
    assert_equal 'docomo', m['agent_os']

    # 'agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'
    m = events[5][2]
    assert_equal 5, m['value']
    assert_equal 'PlayStation Vita', m['agent_name']
    assert_equal 'appliance', m['agent_category']
    assert_equal 'PlayStation Vita', m['agent_os']

    # 'agent' => 'Mozilla/5.0 (compatible; Google Desktop/5.9.1005.12335; http://desktop.google.com/)'
    m = events[6][2]
    assert_equal 6, m['value']
    assert_equal 'Google Desktop', m['agent_name']
    assert_equal 'misc', m['agent_category']
    assert_equal 'UNKNOWN', m['agent_os']

    # 'agent' => 'msnbot/1.1 (+http://search.msn.com/msnbot.htm)'
    m = events[7][2]
    assert_equal 7, m['value']
    assert_equal 'msnbot', m['agent_name']
    assert_equal 'crawler', m['agent_category']
    assert_equal 'UNKNOWN', m['agent_os']
  end

#   # filter & merge
  def test_emit_filter
    d = create_driver(CONFIG2)
    time = Time.parse('2012-07-20 16:40:30').to_i
    d.run(default_tag: 'test.message') do
      d.feed(time, {'value' => 0, 'agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'})
      d.feed(time, {'value' => 1, 'agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'})
      d.feed(time, {'value' => 2, 'agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'})
      d.feed(time, {'value' => 3, 'agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'})
      d.feed(time, {'value' => 4, 'agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'})
      d.feed(time, {'value' => 5, 'agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'})
      d.feed(time, {'value' => 6, 'agent' => 'Mozilla/5.0 (compatible; Google Desktop/5.9.1005.12335; http://desktop.google.com/)'})
      d.feed(time, {'value' => 7, 'agent' => 'msnbot/1.1 (+http://search.msn.com/msnbot.htm)'})
    end

    events = d.events
    assert_equal 6, events.size
    assert_equal 'merged.message', events[0][0]
    assert_equal time, events[0][1]

    # 'agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'
    m = events[0][2]
    assert_equal 8, m.keys.size
    assert_equal 0, m['value']
    assert_equal 'Internet Explorer', m['ua_name']
    assert_equal 'pc', m['ua_category']
    assert_equal 'Windows 8', m['ua_os']
    assert_equal 'NT 6.2', m['ua_os_version']
    assert_equal 'Microsoft', m['ua_vendor']
    assert_equal '10.0', m['ua_version']

    # 'agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = events[1][2]
    assert_equal 1, m['value']
    assert_equal 'Firefox', m['ua_name']
    assert_equal 'pc', m['ua_category']
    assert_equal 'Windows Vista', m['ua_os']
    assert_equal 'NT 6.0', m['ua_os_version']
    assert_equal 'Mozilla', m['ua_vendor']
    assert_equal '9.0.1', m['ua_version']

    # 'agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = events[2][2]
    assert_equal 2, m['value']
    assert_equal 'Firefox', m['ua_name']
    assert_equal 'pc', m['ua_category']
    assert_equal 'Linux', m['ua_os']
    assert_equal 'UNKNOWN', m['ua_os_version']
    assert_equal 'Mozilla', m['ua_vendor']
    assert_equal '9.0.1', m['ua_version']

    # 'agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'
    m = events[3][2]
    assert_equal 3, m['value']
    assert_equal 'Safari', m['ua_name']
    assert_equal 'smartphone', m['ua_category']
    assert_equal 'Android', m['ua_os']
    assert_equal '3.1', m['ua_os_version']
    assert_equal 'Apple', m['ua_vendor']
    assert_equal '4.0', m['ua_version']

    # 'agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'
    m = events[4][2]
    assert_equal 4, m['value']
    assert_equal 'docomo', m['ua_name']
    assert_equal 'mobilephone', m['ua_category']
    assert_equal 'docomo', m['ua_os']
    assert_equal 'UNKNOWN', m['ua_os_version']
    assert_equal 'docomo', m['ua_vendor']
    assert_equal 'N505i', m['ua_version']

    # 'agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'
    m = events[5][2]
    assert_equal 5, m['value']
    assert_equal 'PlayStation Vita', m['ua_name']
    assert_equal 'appliance', m['ua_category']
    assert_equal 'PlayStation Vita', m['ua_os']
    assert_equal '1.51', m['ua_os_version']
    assert_equal 'Sony', m['ua_vendor']
    assert_equal 'UNKNOWN', m['ua_version']
  end

#   # drop & non-merge
  def test_emit_drop
    d = create_driver(CONFIG3)
    time = Time.parse('2012-07-20 16:40:30').to_i
    d.run(default_tag: 'test.message') do
      d.feed(time, {'value' => 0, 'user_agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'})
      d.feed(time, {'value' => 1, 'user_agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'})
      d.feed(time, {'value' => 2, 'user_agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'})
      d.feed(time, {'value' => 3, 'user_agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'})
      d.feed(time, {'value' => 4, 'user_agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'})
      d.feed(time, {'value' => 5, 'user_agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'})
      d.feed(time, {'value' => 6, 'user_agent' => 'Mozilla/5.0 (compatible; Google Desktop/5.9.1005.12335; http://desktop.google.com/)'})
      d.feed(time, {'value' => 7, 'user_agent' => 'msnbot/1.1 (+http://search.msn.com/msnbot.htm)'})
    end

    events = d.events
    assert_equal 6, events.size
    assert_equal 'selected', events[0][0]
    assert_equal time, events[0][1]

    # 'agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'
    m = events[0][2]
    assert_equal 0, m['value']
    assert_equal 2, m.keys.size

    # 'agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = events[1][2]
    assert_equal 1, m['value']

    # 'agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = events[2][2]
    assert_equal 2, m['value']

    # 'agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'
    m = events[3][2]
    assert_equal 3, m['value']

    # 'agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'
    m = events[4][2]
    assert_equal 4, m['value']

    # 'agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'
    m = events[5][2]
    assert_equal 5, m['value']
  end
end
