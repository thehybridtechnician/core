# Copyright 2013, Dell 
# 
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
# 
#  http://www.apache.org/licenses/LICENSE-2.0 
# 
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
# 

class BarclampDns::Database < Role


  def on_node_create(n)
    Rails.logger.info("dns-database: Updating for new node #{n.name}")
    rerun_my_noderoles
  end

  def on_node_change(n)
    Rails.logger.info("dns-database: Updating for new node #{n.name}")
    rerun_my_noderoles
  end

  def on_node_delete(n)
    Rails.logger.info("dns-database: Updating for removed node #{n.name}")
    rerun_my_noderoles
  end

  private

  def rerun_my_noderoles
    hosts = {}
    # Record our host entry information first.
    Role.transaction do
      Node.all.each do |n|
        v4addrs,v6addrs = n.addresses.partition{|a|a.v4?}
        canonical_name = n.name + "."
        hosts[canonical_name] = Hash.new
        hosts[canonical_name]["ip6addr"] = v6addrs.sort.first.addr unless v6addrs.empty?
        hosts[canonical_name]["ip4addr"] = v4addrs.sort.first.addr unless v4addrs.empty?
        if n.alias && !canonical_name.index(n.alias)
          hosts[canonical_name]["alias"] = n.alias
        end
      end
    end
    # Populate the rest of the zone information
    new_sysdata = {
      "crowbar" => {
        "dns" => {
          "hosts" => hosts
        }
      }
    }
    to_enqueue = []
    NodeRole.transaction do
      node_roles.committed.lock(true).each do |nr|
        next if nr.sysdata == new_sysdata
        nr.sysdata = new_sysdata
        nr.save!
        to_enqueue << nr
      end
    end
    to_enqueue.each {|nr| Run.enqueue(nr)}
  end
end

