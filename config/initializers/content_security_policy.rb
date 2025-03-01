# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https, :unsafe_inline, :blob
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval, :blob
    policy.style_src   :self, :https, :unsafe_inline
    policy.frame_src   :self, "*.youtube.com", "*.vimeo.com"
    policy.connect_src :self, "https://appsignal-endpoint.net"
  end
end
