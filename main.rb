#!/usr/bin/ruby
require 'rubygems'
require 'pp'
require 'active_resource'
require 'linode'
require 'logger'
require 'highline/import'

$LOG = Logger.new($stdout)
def error(message)
  $LOG.fatal(message)
  exit
end


slicehost_api_key = if ARGV[0] then ARGV[0] else ask("SLICE HOST API KEY") end
SLICEHOST = "https://"+slicehost_api_key+"@api.slicehost.com/"

linode_api_key = if ARGV[1] then ARGV[1] else ask("LINODE HOST API KEY") end

class Slice < ActiveResource::Base
  self.site = SLICEHOST
end
# Address class is required for Slice class
class Address < String; end

class Zone < ActiveResource::Base
  self.site = SLICEHOST
end

class Record < ActiveResource::Base
  self.site = SLICEHOST
end

def running_record(domain, record, linode_api_key)
  puts record.record_type + " " + record.data  
  l = Linode.new(:api_key => linode_api_key)
  
  case record.record_type.downcase
    when 'srv'
      puts "creating SRV record"
      srvce, protocol = record.name.split(/\./)
      weight, port, target = record.data.split(' ')
      l.domain.resource.create(:DomainID => domain.domainid, :Type => 'SRV', :Name => srvce, :Priority => record.aux, :Target => target, 
                               :Priority => record.aux, :Weight => weight, :Port => port, :Protocol => protocol.sub('_',''), :TTL_sec => record.ttl)
    when 'mx'
      puts "creating MX record"
      l.domain.resource.create(:DomainID => domain.domainid, :Type => 'MX', :Target => record.data[0,record.data.length-1], :Priority => record.aux, :TTL_sec => record.ttl)
    when 'txt', 'cname', 'a'
      puts "creating #{record.record_type} record"
      name = record.a? && record.name == zone.origin ? '' : record.name
      l.domain.resource.create(:DomainID => domain.domainid, :Type => record.record_type, :Name => name, :Target => record.data, :TTL_sec => record.ttl)
  end
end

def running_zone(zone, linode_api_key)
  l = Linode.new(:api_key => linode_api_key)
  error "#{arg} already exists at linode please delete" if l.domain.list().find {|domain| domain.domain == zone.origin }
  puts "Creating #{zone.origin[0, zone.origin.length-1]} @ linode.com"
  domain = l.domain.create(:Domain => zone.origin[0, zone.origin.length-1], :Type => 'Master', :SOA_Email => "dev@oneblackbear.com", :TTL_sec => zone.ttl, :status => 1)
  Record.find(:all, :params => {:zone_id => zone.id}).each do |record|
    running_record(domain, record, linode_api_key)    
  end      
  puts "----"
end

zoneids =  ask("Enter ZONE NAME [can be , seperated list, 'all']")
if zoneids == "all" then
  Zone.all().each do |zone|
    running_zone(zone, linode_api_key);
  end
else
  zoneids.split(",").each do |zoneid|
    if zoneid and zone = Zone.find(:first, :params=>{:origin=>zoneid}) then
      running_zone(zone, linode_api_key)
    end
  end
end



