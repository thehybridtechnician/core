#
# Copyright 2013-4, Dell
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
require 'digest/md5'

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :authenticatable, :confirmable, :database_authenticatable, :lockable, :omniauthable, 
  # :recoverable, :registerable, :rememberable, :timeoutable, :token_authenticatable, 
  # :trackable, :validatable
  devise :database_authenticatable, :registerable,
         :rememberable, :trackable, :validatable, :recoverable,
         :lockable, :timeoutable, :authentication_keys => [:username]

  attr_accessor :admin_reset_password

  # user control for UI, split test and site configuration
  # see https://github.com/ledermann/rails-settings for help
  has_settings do |s|
    s.key :ui,        :defaults => { :refresh => 15000, :fast_refresh => 5000, :debug => true, :edge => true, :test => true, :noop_roles => true }
    s.key :errors,    :defaults => { :expand => true }
    s.key :docs,      :defaults => { :sources => true, :rebuild => true }
    s.key :network,   :defaults => { :v6prefix => {'admin'=>'auto' } }
  end

  # Setup accessible (or protected) attributes for your model
  
  validates :username, :uniqueness => {:case_sensitive => false}, :presence => true
  DIGEST_REALM = "Crowbar"
  
  scope  :admin,              -> { where(:is_admin => true) }
 
  def self.name_column
    :username
  end
  
  def self.find_by_id_or_username(id)
    if id.kind_of?(Integer)
      ret = find(id)
    elsif /^[0-9]+$/ =~ id
      ret = find(id.to_i)
    else
      ret = where(:username => id).first
    end
   raise ActiveRecord::RecordNotFound.new(I18n.t('api.by_id_or_username_record_not_found', :id_username=>id)) if ret.nil?
   ret
  end

  def digest_password(new_pass)
    self.encrypted_password = digester(new_pass)
  end
  
  def email_required?
    false
  end
  
  def password_required?
     (!persisted? || !password.nil? || !password_confirmation.nil?) || admin_reset_password?
  end

  def admin_reset_password?
    @admin_reset_password == true
  end
 
  def valid_password?(password)
    # try default password test first DatabaseAuthenticatable valid_password?
    # see https://github.com/plataformatec/devise/blob/master/lib/devise/models/database_authenticatable.rb
    return false if encrypted_password.blank?
    begin
      bcrypt   = ::BCrypt::Password.new(encrypted_password)
      password = ::BCrypt::Engine.hash_secret("#{password}#{self.class.pepper}", bcrypt.salt)
      return true if Devise.secure_compare(password, encrypted_password)
    rescue
      # ignore, keep going
    end
    
    # now the compromise, fall back to MD5 emthod as backup
    return digester(password).eql?(encrypted_password)
  end

  private
 
  def digester(pass)
    Digest::MD5.hexdigest([username,DIGEST_REALM,pass].join(":"))
  end
 
end

