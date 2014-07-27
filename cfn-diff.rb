#!/usr/bin/env ruby

class Hash
 
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

new_h = new_template()
old_h = actual_template()

puts new_h.deep_diff(old_h)
