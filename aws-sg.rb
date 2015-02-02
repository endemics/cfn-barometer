#!/usr/bin/env ruby

require 'json'
require 'pp'

$profile = 'default'
regions=['eu-west-1']

sg_list = []

def get_sg (region)
    sg_json = `aws ec2  describe-security-groups --region #{region} --profile #{$profile}`
    hash = JSON.parse(sg_json)
    if hash.has_key?('SecurityGroups')
      return hash['SecurityGroups']
    else
      return []
    end
end

def description_to_name (string)
  string.gsub(/[^[A-Za-z0-9]]/,'')
end

def translate_egress(rules, is_vpc)
  new_rules = []
  if is_vpc 
    rules.each do |rule|
      rule['IpRanges'].each do |cidr|
        new_rule = Hash.new()
        new_rule['FromPort'] = rule['FromPort']
        new_rule['ToPort'] = rule['ToPort']
        new_rule['IpProtocol'] = rule['IpProtocol']
        new_rule['CidrIp'] = cidr['CidrIp']
        new_rules << new_rule
      end
      rule['UserIdGroupPairs'].each do |group|
        new_rule = Hash.new()
        new_rule['FromPort'] = rule['FromPort']
        new_rule['ToPort'] = rule['ToPort']
        new_rule['IpProtocol'] = rule['IpProtocol']
        new_rule['DestinationSecurityGroupId'] = group['GroupId']
        new_rules << new_rule
      end
    end
  end
  return new_rules
end

def translate_ingress(rules, is_vpc)
  new_rules = []
  rules.each do |rule|
    rule['IpRanges'].each do |cidr|
      new_rule = Hash.new()
      new_rule['CidrIp'] = cidr['CidrIp']
      new_rule['FromPort'] = rule['FromPort']
      new_rule['IpProtocol'] = rule['IpProtocol']
      new_rule['ToPort'] = rule['ToPort']
      new_rules << new_rule
    end
    rule['UserIdGroupPairs'].each do |group|
      new_rule = Hash.new()
      new_rule['FromPort'] = rule['FromPort']
      new_rule['IpProtocol'] = rule['IpProtocol']
      if is_vpc
        new_rule['SourceSecurityGroupId'] = group['GroupId']
      else
        new_rule['SourceSecurityGroupName'] = group['GroupName']
      end
      new_rule['ToPort'] = rule['ToPort']
      new_rules << new_rule
    end
  end
  return new_rules
end

def to_cfn (sg)
    cfn_sg = Hash.new()
    vpc = false
    if sg.has_key?('VpcId')
      vpc = true
    end
    cfn_sg['Type'] = 'AWS::EC2::SecurityGroup'
    cfn_sg['Properties'] = Hash.new()
    cfn_sg['Properties']['GroupDescription'] = sg['Description'] if sg['Description']
    cfn_sg['Properties']['SecurityGroupIngress'] = translate_ingress(sg['IpPermissions'], vpc)
    cfn_sg['Properties']['SecurityGroupEgress'] = translate_egress(sg['IpPermissionsEgress'], vpc)
    cfn_sg['Properties']['Tags'] = sg['Tags'] if sg['Tags']
    cfn_sg['Properties']['VpcId'] = sg['VpcId'] if vpc
    out = { description_to_name(sg['Description']) => cfn_sg }
end

regions.each do |region|
  (sg_list << get_sg(region)).flatten!
end

tmpl = {
  'AWSTemplateFormatVersion' => '2010-09-09',
  'Description'              => 'Security Group Extract',
  'Resources'                => Hash.new()
}

sg_list.each do |sg|
  tmpl['Resources'].merge!(to_cfn(sg))
end

puts JSON.pretty_generate(tmpl)
#print tmpl.to_json
