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

class NodeRolesController < ApplicationController

  def index
    @list = (if params.key? :node_id
              Node.find_key(params[:node_id]).node_roles.current
            elsif params.key? :deployment_id
              Deployment.find_key(params[:deployment_id]).node_roles
            else
              NodeRole.all
            end).order("cohort asc, id asc")
    respond_to do |format|
      format.html { }
      format.json { render api_index NodeRole, @list }
    end
  end

  def show
    if params.key? :node_id
      node = Node.find_key params[:node_id]
      raise "could not find node #{params[:node_id]}" unless node
      role = Role.find_key params[:id]
      raise "could not find role #{params[:id]}" unless role
      @node_role = NodeRole.find_by!(node_id: node.id, role_id: role.id)
    else
      @node_role = NodeRole.find_key params[:id]
    end
    respond_to do |format|
      format.html {  }
      format.json { render api_show @node_role }
    end
  end

  def create
    # helpers to allow create by names instead of IDs
    depl = nil
    if params.key? :deployment_id
      depl = Deployment.find_key(params[:deployment_id])
    elsif params.key? :deployment
      depl = Deployment.find_key(params[:deployment])
    end
    node = Node.find_key(params[:node] || params[:node_id])
    role = Role.find_key(params[:role] || params[:role_id])
    depl ||= node.deployment
    NodeRole.locked_transaction do
      @node_role = role.add_to_node_in_deployment(node,depl)
      if params[:data]
        @node_role.data = params[:data]
        @node_role.save!
      end
    end
    respond_to do |format|
      format.html { redirect_to deployment_path(depl.id) }
      format.json { render api_show @node_role }
    end
    
  end

  def update
    @node_role = NodeRole.find_key params[:id]
    # if you've been passed data then save it
    if params[:data]
      NodeRole.transaction do
        @node_role.data = params[:data]
        @node_role.save!
        flash[:notice] = I18n.t 'saved', :scope=>'layouts.node_roles.show'
      end
    end
    respond_to do |format|
      format.html { render 'show' }
      format.json { render api_show @node_role }
    end
  end

  def destroy
    unless Rails.env.development?
      render  api_not_supported("delete", "node_role")
    else
      render api_delete NodeRole
    end
  end

  def retry
    @node_role = NodeRole.find_key params[:node_role_id]
    @node_role.todo!
    respond_to do |format|
      format.html { render :action => :show }
      format.json { render api_show @node_role }
    end

  end

  def anneal
    respond_to do |format|
      format.html { }
      format.json {
        if NodeRole.committed.in_state(NodeRole::TODO).count > 0
          render :json => { "message" => "scheduled" }, :status => 202
        elsif NodeRole.committed.in_state(NodeRole::TRANSITION).count > 0
          render :json => { "message" => "working" }, :status => 202
        elsif NodeRole.committed.in_state(NodeRole::ERROR).count > 0
          render :json => { "message" => "failed" }, :status => 409
        else
          render :json => { "message" => "finished" }, :state => 200
        end
      }
    end
  end

end

