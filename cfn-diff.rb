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

def actual_template()
  # If retrieved from `aws cloudformation get-template` we need to extract "TemplateBody"
  file = File.open("./fixtures/template_base_instance.json", "rb")
  contents = file.read
  JSON.parse!(contents)
end

def new_template()
  file = File.open("./fixtures/template_add_instance.json", "rb")
  contents = file.read
  JSON.parse!(contents)
end

# print modifications between new and old
# (in this order)
def modifications(hash)
    hash.each do |k,v|
      # if we have an array then we have a modification
      # (and the array has 2 elements)
      if v.kind_of?(Array)
        if (v[0] and v[1])
          puts "M #{k}"
        elsif v[0]
          puts "A #{k}"
        else
          puts "D #{k}"
        end
      end
      # If we have a hash then we need to explore further
      if v.kind_of?(Hash)
        modifications(v)
      end
    end
end

new_h = new_template()
old_h = actual_template()

modifications(new_h.deep_diff(old_h))
