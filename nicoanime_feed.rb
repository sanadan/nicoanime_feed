#!/usr/bin/env ruby

require 'rss'
require 'mechanize'

$title = 'アニメ - ニコニコチャンネル'
$uri = 'http://ch.nicovideo.jp/search_video/%E3%82%A2%E3%83%8B%E3%83%A1?mode=t&page=1&sort=f&order=d'
# cronではリクエストuriが取れなくなったので、参照先uriにした
#$about = ENV['REQUEST_SCHEME'].to_s + '://' + ENV['HTTP_HOST'].to_s + ENV['REQUEST_URI'].to_s
$about = $uri
$description = 'ニコニコチャンネルのアニメの新着をFeedにします。'
$author = 'sanadan'

def main
  web = Mechanize.new
  page = web.get( $uri )

  feed_items = []

  # 動画ID抽出
  id_list = []
  page.body.scan(/watch\/[a-z][a-z]\d+/) do |id|
    id_list << id
  end
  id_list.uniq!
#p id_list

  # 動画情報取得
  id_list.each do |id|
    info_uri = id.sub( /watch/, 'http://www.nicovideo.jp/api/getthumbinfo' )
    info_html = web.get( info_uri )
    info = Nokogiri.XML( info_html.body )
    next if info.at( 'nicovideo_thumb_response' )[ 'status' ] != 'ok' # 削除されているなら次へ
#p info.at( 'title' )

    data = {}
    data[ 'id' ] = id[ 6 .. -1 ]
    data[ 'title' ] = CGI.unescapeHTML( info.at( 'title' ).inner_text )
#p data[ 'title' ]
    data[ 'link' ] = 'http://www.nicovideo.jp/watch/' + data[ 'id' ]
    date = info.at( 'first_retrieve' ).inner_text
    data[ 'date' ] = Time.parse( date )
#p data[ 'date' ]

    # html組み立て
    content = '<img align="left" src="' + info.at( 'thumbnail_url' ).inner_text + '">'
    content += '　投稿日時：' + date.gsub( /T(.*)\+.*/, ' \1' )
    content += '<br>'
    content += '　再生時間：' + info.at( 'length' ).inner_text
    content += '<br>'
    content += '　　再生数：' + info.at( 'view_counter' ).inner_text
    content += '<br>'
    content += '　コメント：' + info.at( 'comment_num' ).inner_text
    content += '<br>'
    content += 'マイリスト：' + info.at( 'mylist_counter' ).inner_text
    content += '<br>'
    content += info.at( 'description' ).inner_text
    content += '<br>'
#p content

    data[ 'content' ] = content

    $items << data
  end

  raise "検索結果が正しく取得できませんでした" if $items.size == 0
end

# entry
$items = []
begin
  main
rescue
  item = {}
  item[ 'id' ] = Time.now.strftime( '%Y%m%d%H%M%S' )
  item[ 'title' ] = $!.to_s
  item[ 'content' ] = $!.to_s
  $!.backtrace.each do |trace|
    item[ 'content' ] += '<br>'
    item[ 'content' ] += trace
  end
  item[ 'date' ] = Time.now
  $items << item
end

feed = RSS::Maker.make( 'atom' ) do |maker|
  maker.channel.about = $about
  maker.channel.title = $title
  maker.channel.description = $description
  maker.channel.link = $uri
  maker.channel.updated = Time.now
  maker.channel.author = $author
  $items.each do |data|
    item = maker.items.new_item
    item.id = data[ 'id' ]
    item.title = data[ 'title' ]
    item.link = data[ 'link' ] if data[ 'link' ]
    item.content.content = data[ 'content' ]
    item.content.type = 'html'
    item.date = data[ 'date' ]
  end
end

File.write( '/var/www/nicoanime_feed/html/feed.xml', feed )

