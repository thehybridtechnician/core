# Copyright 2014, Dell
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

class NetworkAllocation < ActiveRecord::Base

  validate :sanity_check_address
  
  belongs_to :network_range
  belongs_to :node

  alias_attribute :range,       :network_range

  scope  :node,     ->(n)  { where(:node_id => n.id) }
  scope  :network,  ->(net){ joins(:network_range).where('network_ranges.network_id' => net.id) }

  def self.locked_transaction(&block)
    begin
      Run.transaction(isolation: :serializable) do
        ActiveRecord::Base.connection.execute("LOCK TABLE network_allocations")
        yield if block_given?
      end
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("Run: Deadlock detected, retrying: #{e.message}")
      retry
    end
  end

  def address
    IP.coerce(read_attribute("address"))
  end

  def address=(addr)
    write_attribute("address",IP.coerce(addr).to_s)
  end

  def network
    network_range.network
  end

  private

  def sanity_check_address
    unless network_range === address
      errors.add("Allocation #{network.name}.#{network_range.name}.{address.to_s} not in parent range!")
    end
  end
  
end
