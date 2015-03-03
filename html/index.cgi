#!/usr/bin/env ruby
# coding: utf-8 　

puts( 'Content-type: application/atom+xml' )
puts()
puts( File.read( 'feed.xml' ) )

