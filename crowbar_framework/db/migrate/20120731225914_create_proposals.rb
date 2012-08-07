# Copyright 2012, Dell
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
class CreateProposals < ActiveRecord::Migration
  def change
    #####
    #  proposals, attached to barclamps.
    #  proposal_configs hold the actual date, with revision counts and node references.
    create_table :proposals do |t|
      t.references  :barclamp
      t.string      :name
      t.string      :description
      t.integer     :status
      t.integer     :last_applied_rev
      t.references  :active_config
      t.references  :current_config
      t.timestamps
    end
  end
end
