#!/usr/bin/ruby
# vim: set fileencoding=utf-8 :

# require {{{
require 'faraday'
require 'find'
require 'json'
require 'nokogiri'
require 'optparse'
require 'pathname'
require 'shellwords'
require 'uri'
# }}}

# Option parser {{{
class Options
  attr_reader :keyword, :width, :height, :pages, :offset, :chrysoberyl, :size, :minimum

  def initialize (argv)
    init
    parse(argv)
  end

  def range
    self.offset ... (self.offset + self.pages)
  end

  def size_char
    @size and @size[0]
  end

  private
  def init
    @pages = 1
    @offset = 0
  end

  def parse (argv)
    op = OptionParser.new do |opt|
      opt.on('-w WIDTH', '--width WIDTH',  'Image width') {|v| @width = v.to_i }
      opt.on('-h HEIGHT', '--height HEIGHT',  'Image height') {|v| @height = v.to_i }
      opt.on('-p PAGES', '--pages PAGES',  'Pages') {|v| @pages = v.to_i }
      opt.on('-s SIZE', '--size SIZE',  'Size (large/middle/small/icon)') {|v| @size = v }
      opt.on('-m MINIMUM', '--minimum MINIMUM',  'Minimum (qsvga/vga/svga/xga/2mp/4mp/6mp/8mp/10mp/12mp/15mp/20mp/40mp/70mp)') {|v| @minimum = v }
      opt.on('-o OFFSET', '--offset PAGES',  'Offset') {|v| @offset = v.to_i }
      opt.on('-c', '--chrysoberyl') { @chrysoberyl = true }
      opt.parse!(argv)
    end

    if argv.empty?
      puts(op)
      exit 1
    end

    @keyword = argv.join(' ')
  end
end
# }}}

# App {{{
class App
  BASE_URL = 'https://www.google.co.jp/search'

  def initialize (options)
    @options = options
    Faraday.default_connection = Faraday.new(
      options = {
        :headers => {
          :user_agent => "Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0"
        }
      }
    )
  end

  def start
    @options.range.each_with_index do
      |page, index|
      sleep(1.0) if 0 < index
      self.get(page)
    end
  end

  def get (page)
    url = build_url(page)
    STDERR.puts(url)

    response = Faraday.get(url, {})
    raise "HTTP Error: #{response.status}" if response.status != 200
    html = Nokogiri::HTML(response.body)
    # File.write('/tmp/xmosh/t.html', response.body)

    # html = Nokogiri::HTML(File.read('/tmp/xmosh/t.html'))

    html.css('.rg_meta.notranslate').each do
      |element|
      entry = JSON.parse(element.text)
      if @options.chrysoberyl
        args = {
          :BING => 1,
          :NAME => entry['pt'],
          :HOST_PAGE => entry['ru'],
        }.map do
          |k, v|
          "--meta #{k}=#{v.to_s.shellescape}"
        end.join(' ')
        puts("@push-url #{args} #{entry['ou'].shellescape}")
      else
        puts(entry['ou'])
      end
    end
  end

  def build_url (page)
    params = {
      :q => @options.keyword,
      :tbm => 'isch',
      :ijn => (page || 0),
    }
    if @options.width or @options.height or @options.minimum or @options.size_char
      tbs = {:isz => 'ex'}
      tbs[:iszw] = @options.width if @options.width
      tbs[:iszh] = @options.height if @options.height
      tbs[:isz] = @options.size_char if @options.size_char
      if @options.minimum
        tbs[:isz] = 'lt'
        tbs[:islt] = @options.minimum
      end
      tbs_query = tbs.map {|k, v| '%s:%s' % [k, v] } .join(',')
      params[:tbs] = tbs_query
    end
    query = params.map {|k, v| '%s=%s' % [k, v].map {|it| URI.escape(it.to_s) } } .join('&')
    BASE_URL + '?' + query
  end
end
# }}}


if __FILE__ == $0
  App.new(Options.new(ARGV)).start
end

