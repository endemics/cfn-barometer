#!/usr/bin/env ruby

class Hash

  # from https://gist.github.com/henrik/146844
  def deep_diff(b)
    a = self
    (a.keys | b.keys).inject({}) do |diff, k|
      if a[k] != b[k]
        if a[k].respond_to?(:deep_diff) && b[k].respond_to?(:deep_diff)
          diff[k] = a[k].deep_diff(b[k])
        else
          diff[k] = [a[k], b[k]]
        end
      end
      diff
    end
  end
 
end

require 'pp'
require 'json'

def actual_template(opts)
  profile = ''
  if opts[:profile] then
    profile = "--profile #{opts[:profile]}"
  end
  region = "--region #{opts[:region]}"
  stack = "--stack-name #{opts[:stack]}"
  cmd = "aws cloudformation get-template #{profile} #{stack} #{region}"

  tpl = `#{cmd}`
  JSON.parse!(tpl['TemplateBody'])
end

def new_template(file)
  file = File.open(file, "rb")
  contents = file.read
  JSON.parse!(contents)
end

# print modifications between new and old
# (in this order)
def modifications(hash, path='')
    hash.each do |k,v|
      if path != ''
        cur_path = "#{path}/#{k}"
      else
        cur_path = "#{k}"
      end
      # if we have an array then we have a modification
      # (and the array has 2 elements)
      if v.kind_of?(Array)
        if (v[0] and v[1])
          puts "M #{cur_path}"
        elsif v[0]
          puts "A #{cur_path}"
        else
          puts "D #{cur_path}"
        end
      end
      # If we have a hash then we need to explore further
      if v.kind_of?(Hash)
        modifications(v, cur_path)
      end
    end
end

require 'optparse'

usage = "Usage: cfn-diff [options] (-s|--stack) STACKNAME TEMPLATE"

options = {}
options[:region] = 'us-east-1'
options[:help] = false

opt_parse = OptionParser.new do |opts|
  opts.banner = usage

  opts.on('-r REGION', "--region REGION", "AWS region (default to us-east-1)") do |r|
    options[:region] = r
  end

  opts.on('-s STACKNAME', "--stack STACKNAME", "CFN stack name (mandatory)") do |s|
    options[:stack] = s
  end

  opts.on('-p PROFILE', "--profile PROFILE", "AWS profile to use") do |p|
    options[:profile] = p
  end

  opts.on('-h', "--help") do |h|
    options[:help] = h
    puts opts
  end

  options
end

opt_parse.parse!

unless options[:help] then
  options.fetch(:stack) do
    abort("Missing STACKNAME!\n#{usage}")
  end
  if ARGV.size < 1 then
    abort("Missing TEMPLATE!\n#{usage}")
  end
end

new_h = new_template(ARGV[0])
old_h = actual_template(options)

modifications(new_h['Resources'].deep_diff(old_h['Resources']))
