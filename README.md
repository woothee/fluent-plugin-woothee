# fluent-plugin-woothee

## WootheeOutput

'fluent-plugin-woothee' is a Fluentd plugin to parse UserAgent strings and to filter/drop specified categories of user terminals (like 'pc', 'smartphone' and so on).

'woothee' is multi-language user-agent strings parser project. See: https://github.com/woothee/woothee

## Configuration

To add woothee parser result into matched messages:

    <match input.**>
      type woothee
      key_name agent
      remove_prefix input
      add_prefix merged
      merge_agent_info yes
    </match>

Output messages with tag 'merged.**' has attributes like 'agent\_name', 'agent\_category' and 'agent\_os' from woothee parser result. If you want to change attribute names, or want to merge more attributes of browser vendor and its version, write configurations as below:

    <match input.**>
      type woothee
      key_name agent
      remove_prefix input
      add_prefix merged
      merge_agent_info yes
      out_key_name ua_name
      out_key_category ua_category
      out_key_os ua_os
      out_key_os_version ua_os_version
      out_key_version ua_version
      out_key_vendor ua_vendor
    </match>

To re-emit messages with specified user-agent categories (and merge woothee parser result), configure like this:

    <match input.**>
      type woothee
      key_name agent
      filter_categories pc,smartphone,mobilephone,appliance
      remove_prefix input
      add_prefix merged
      merge_agent_info yes
    </match>

Or, you can specify categories to drop (and not to merge woothee result):

    <match input.**>
      type woothee
      key_name agent
      drop_categories crawler
      remove_prefix input
      add_prefix merged
      merge_agent_info false # default
    </match>

### Fast Crawler Filter

If you want to drop __almost__ all of messages with crawler's user-agent, and not to merge woothee result, you just specify plugin type:

    <match input.**>
      type woothee_fast_crawler_filter
      key_name useragent
      tag filtered
    </match>

'fluent-plugin-woothee' uses 'Woothee.is_crawler' of woothee with this configuration, fast and incomplete method to judge user-agent is crawler or not.
If you want to drop all of crawlers completely, specify 'type woothee' and 'drop_categories crawler'.

## TODO

* patches welcome!

## Copyright

* Copyright (c) 2012- TAGOMORI Satoshi (tagomoris)
* License
  * Apache License, Version 2.0
