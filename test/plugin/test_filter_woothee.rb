require 'helper'

class Fluent::WootheeFilterTest < Test::Unit::TestCase
  # fast crawler filter
  CONFIG0 = %[
type woothee_fast_crawler_filter
key_name useragent
]

  # through & merge
  CONFIG1 = %[
type woothee
key_name agent
merge_agent_info yes
]

  # filter & merge
  CONFIG2 = %[
type woothee
key_name agent
filter_categories pc,smartphone,mobilephone,appliance
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
]

  def setup
    omit("Use fluentd v0.12 or later") unless defined?(Fluent::Filter)

    Fluent::Test.setup
  end

  def create_driver(conf=CONFIG1,tag='test')
    Fluent::Test::FilterTestDriver.new(Fluent::WootheeFilter, tag).configure(conf)
  end

  class TestConfigure < self
    def test_fast_crawer_filter
      d = create_driver CONFIG0
      assert_equal true, d.instance.fast_crawler_filter_mode
      assert_equal 'useragent', d.instance.key_name
    end

    def test_through_and_merge
      d = create_driver CONFIG1
      assert_equal false, d.instance.fast_crawler_filter_mode
      assert_equal 'agent', d.instance.key_name

      assert_equal 0, d.instance.filter_categories.size
      assert_equal 0, d.instance.drop_categories.size
      assert_equal :through, d.instance.mode

      assert_equal true, d.instance.merge_agent_info
      assert_equal 'agent_name', d.instance.out_key_name
      assert_equal 'agent_category', d.instance.out_key_category
      assert_equal 'agent_os', d.instance.out_key_os
      assert_nil d.instance.out_key_version
      assert_nil d.instance.out_key_vendor
    end

    def test_filter_and_merge
      d = create_driver CONFIG2
      assert_equal false, d.instance.fast_crawler_filter_mode
      assert_equal 'agent', d.instance.key_name

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
    end

    def test_drop_and_non_merge
      d = create_driver CONFIG3
      assert_equal false, d.instance.fast_crawler_filter_mode
      assert_equal 'user_agent', d.instance.key_name

      assert_equal 0, d.instance.filter_categories.size
      assert_equal 2, d.instance.drop_categories.size
      assert_equal [:crawler,:misc], d.instance.drop_categories
      assert_equal :drop, d.instance.mode

      assert_equal false, d.instance.merge_agent_info
    end
  end

  def test_filter_fast_crawler_filter_stream
    d = create_driver CONFIG0
    time = Time.parse('2012-07-20 16:19:00').to_i
    d.run do
      d.filter({'useragent' => 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)', 'value' => 1}, time)
      d.filter({'useragent' => 'Mozilla/5.0 (compatible; Yahoo! Slurp; http://help.yahoo.com/help/us/ysearch/slurp)', 'value' => 2}, time)
      d.filter({'useragent' => 'Mozilla/5.0 (iPad; U; CPU OS 4_3_2 like Mac OS X; ja-jp) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8H7 Safari/6533.18.5', 'value' => 3}, time)
      d.filter({'useragent' => 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0)', 'value' => 4}, time)
      d.filter({'useragent' => 'Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)', 'value' => 5}, time)
      d.filter({'useragent' => 'Mozilla/5.0 (compatible; Rakutenbot/1.0; +http://dynamic.rakuten.co.jp/bot.html)', 'value' => 6}, time)
      d.filter({'useragent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_4; ja-jp) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.2 Safari/525.20.1', 'value' => 7}, time)
      d.filter({'useragent' => 'Yeti/1.0 (NHN Corp.; http://help.naver.com/robots/)', 'value' => 8}, time)
    end

    filtered = d.filtered_as_array
    assert_equal 4, filtered.size

    assert_equal 'test', filtered[0][0]
    assert_equal time, filtered[0][1]
    assert_equal 'Mozilla/5.0 (iPad; U; CPU OS 4_3_2 like Mac OS X; ja-jp) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8H7 Safari/6533.18.5', filtered[0][2]['useragent']
    assert_equal 3, filtered[0][2]['value']
    assert_equal 2, filtered[0][2].keys.size

    assert_equal 4, filtered[1][2]['value']
    assert_equal 6, filtered[2][2]['value']
    assert_equal 7, filtered[3][2]['value']
  end

  # through & merge
  def test_filter_through
    d = create_driver(CONFIG1, 'test.message')
    time = Time.parse('2012-07-20 16:40:30').to_i
    d.run do
      d.filter({'value' => 0, 'agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'}, time)
      d.filter({'value' => 1, 'agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'}, time)
      d.filter({'value' => 2, 'agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'}, time)
      d.filter({'value' => 3, 'agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'}, time)
      d.filter({'value' => 4, 'agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'}, time)
      d.filter({'value' => 5, 'agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'}, time)
      d.filter({'value' => 6, 'agent' => 'Mozilla/5.0 (compatible; Google Desktop/5.9.1005.12335; http://desktop.google.com/)'}, time)
      d.filter({'value' => 7, 'agent' => 'msnbot/1.1 (+http://search.msn.com/msnbot.htm)'}, time)
    end

    filtered = d.filtered_as_array
    assert_equal 8, filtered.size
    assert_equal 'test.message', filtered[0][0]
    assert_equal time, filtered[0][1]

    # 'agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'
    m = filtered[0][2]
    assert_equal 0, m['value']
    assert_equal 'Internet Explorer', m['agent_name']
    assert_equal 'pc', m['agent_category']
    assert_equal 'Windows 8', m['agent_os']
    assert_equal 5, m.keys.size

    # 'agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = filtered[1][2]
    assert_equal 1, m['value']
    assert_equal 'Firefox', m['agent_name']
    assert_equal 'pc', m['agent_category']
    assert_equal 'Windows Vista', m['agent_os']

    # 'agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = filtered[2][2]
    assert_equal 2, m['value']
    assert_equal 'Firefox', m['agent_name']
    assert_equal 'pc', m['agent_category']
    assert_equal 'Linux', m['agent_os']

    # 'agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'
    m = filtered[3][2]
    assert_equal 3, m['value']
    assert_equal 'Safari', m['agent_name']
    assert_equal 'smartphone', m['agent_category']
    assert_equal 'Android', m['agent_os']

    # 'agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'
    m = filtered[4][2]
    assert_equal 4, m['value']
    assert_equal 'docomo', m['agent_name']
    assert_equal 'mobilephone', m['agent_category']
    assert_equal 'docomo', m['agent_os']

    # 'agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'
    m = filtered[5][2]
    assert_equal 5, m['value']
    assert_equal 'PlayStation Vita', m['agent_name']
    assert_equal 'appliance', m['agent_category']
    assert_equal 'PlayStation Vita', m['agent_os']

    # 'agent' => 'Mozilla/5.0 (compatible; Google Desktop/5.9.1005.12335; http://desktop.google.com/)'
    m = filtered[6][2]
    assert_equal 6, m['value']
    assert_equal 'Google Desktop', m['agent_name']
    assert_equal 'misc', m['agent_category']
    assert_equal 'UNKNOWN', m['agent_os']

    # 'agent' => 'msnbot/1.1 (+http://search.msn.com/msnbot.htm)'
    m = filtered[7][2]
    assert_equal 7, m['value']
    assert_equal 'msnbot', m['agent_name']
    assert_equal 'crawler', m['agent_category']
    assert_equal 'UNKNOWN', m['agent_os']
  end

  # filter & merge
  def test_filter_stream
    d = create_driver(CONFIG2, 'test.message')
    time = Time.parse('2012-07-20 16:40:30').to_i
    d.run do
      d.filter({'value' => 0, 'agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'}, time)
      d.filter({'value' => 1, 'agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'}, time)
      d.filter({'value' => 2, 'agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'}, time)
      d.filter({'value' => 3, 'agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'}, time)
      d.filter({'value' => 4, 'agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'}, time)
      d.filter({'value' => 5, 'agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'}, time)
      d.filter({'value' => 6, 'agent' => 'Mozilla/5.0 (compatible; Google Desktop/5.9.1005.12335; http://desktop.google.com/)'}, time)
      d.filter({'value' => 7, 'agent' => 'msnbot/1.1 (+http://search.msn.com/msnbot.htm)'}, time)
    end

    filtered = d.filtered_as_array
    assert_equal 6, filtered.size
    assert_equal 'test.message', filtered[0][0]
    assert_equal time, filtered[0][1]

    # 'agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'
    m = filtered[0][2]
    assert_equal 8, m.keys.size
    assert_equal 0, m['value']
    assert_equal 'Internet Explorer', m['ua_name']
    assert_equal 'pc', m['ua_category']
    assert_equal 'Windows 8', m['ua_os']
    assert_equal 'NT 6.2', m['ua_os_version']
    assert_equal 'Microsoft', m['ua_vendor']
    assert_equal '10.0', m['ua_version']

    # 'agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = filtered[1][2]
    assert_equal 1, m['value']
    assert_equal 'Firefox', m['ua_name']
    assert_equal 'pc', m['ua_category']
    assert_equal 'Windows Vista', m['ua_os']
    assert_equal 'NT 6.0', m['ua_os_version']
    assert_equal 'Mozilla', m['ua_vendor']
    assert_equal '9.0.1', m['ua_version']

    # 'agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = filtered[2][2]
    assert_equal 2, m['value']
    assert_equal 'Firefox', m['ua_name']
    assert_equal 'pc', m['ua_category']
    assert_equal 'Linux', m['ua_os']
    assert_equal 'UNKNOWN', m['ua_os_version']
    assert_equal 'Mozilla', m['ua_vendor']
    assert_equal '9.0.1', m['ua_version']

    # 'agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'
    m = filtered[3][2]
    assert_equal 3, m['value']
    assert_equal 'Safari', m['ua_name']
    assert_equal 'smartphone', m['ua_category']
    assert_equal 'Android', m['ua_os']
    assert_equal '3.1', m['ua_os_version']
    assert_equal 'Apple', m['ua_vendor']
    assert_equal '4.0', m['ua_version']

    # 'agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'
    m = filtered[4][2]
    assert_equal 4, m['value']
    assert_equal 'docomo', m['ua_name']
    assert_equal 'mobilephone', m['ua_category']
    assert_equal 'docomo', m['ua_os']
    assert_equal 'UNKNOWN', m['ua_os_version']
    assert_equal 'docomo', m['ua_vendor']
    assert_equal 'N505i', m['ua_version']

    # 'agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'
    m = filtered[5][2]
    assert_equal 5, m['value']
    assert_equal 'PlayStation Vita', m['ua_name']
    assert_equal 'appliance', m['ua_category']
    assert_equal 'PlayStation Vita', m['ua_os']
    assert_equal '1.51', m['ua_os_version']
    assert_equal 'Sony', m['ua_vendor']
    assert_equal 'UNKNOWN', m['ua_version']
  end

  # drop & non-merge
  def test_filter_drop
    d = create_driver(CONFIG3, 'test.message')
    time = Time.parse('2012-07-20 16:40:30').to_i
    d.run do
      d.filter({'value' => 0, 'user_agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'}, time)
      d.filter({'value' => 1, 'user_agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'}, time)
      d.filter({'value' => 2, 'user_agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'}, time)
      d.filter({'value' => 3, 'user_agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'}, time)
      d.filter({'value' => 4, 'user_agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'}, time)
      d.filter({'value' => 5, 'user_agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'}, time)
      d.filter({'value' => 6, 'user_agent' => 'Mozilla/5.0 (compatible; Google Desktop/5.9.1005.12335; http://desktop.google.com/)'}, time)
      d.filter({'value' => 7, 'user_agent' => 'msnbot/1.1 (+http://search.msn.com/msnbot.htm)'}, time)
    end

    filtered = d.filtered_as_array
    assert_equal 6, filtered.size
    assert_equal 'test.message', filtered[0][0]
    assert_equal time, filtered[0][1]

    # 'agent' => 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)'
    m = filtered[0][2]
    assert_equal 0, m['value']
    assert_equal 2, m.keys.size

    # 'agent' => 'Mozilla/5.0 (Windows NT 6.0; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = filtered[1][2]
    assert_equal 1, m['value']

    # 'agent' => 'Mozilla/5.0 (Ubuntu; X11; Linux i686; rv:9.0.1) Gecko/20100101 Firefox/9.0.1'
    m = filtered[2][2]
    assert_equal 2, m['value']

    # 'agent' => 'Mozilla/5.0 (Linux; U; Android 3.1; ja-jp; L-06C Build/HMJ37) AppleWebKit/534.13 (KHTML, like Gecko) Version/4.0 Safari/534.13'
    m = filtered[3][2]
    assert_equal 3, m['value']

    # 'agent' => 'DoCoMo/1.0/N505i/c20/TB/W24H12'
    m = filtered[4][2]
    assert_equal 4, m['value']

    # 'agent' => 'Mozilla/5.0 (PlayStation Vita 1.51) AppleWebKit/531.22.8 (KHTML, like Gecko) Silk/3.2'
    m = filtered[5][2]
    assert_equal 5, m['value']
  end
end
