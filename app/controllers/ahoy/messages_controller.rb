module Ahoy
  class MessagesController < ActionController::Base
    before_action :set_message

    def open
      if @message && !@message.opened_at
        @message.opened_at = Time.now
        @message.save!
      end
      publish :open
      send_data Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="), type: "image/gif", disposition: "inline"
    end

    def click
      if @message && !@message.clicked_at
        @message.clicked_at = Time.now
        @message.opened_at ||= @message.clicked_at
        @message.save!
      end
      url = params[:url].to_s

      user_signature = params[:signature].to_s

      # transition to HMAC-SHA256
      digest = user_signature.length == 40 ? "SHA1" : "SHA256"
      signature = OpenSSL::HMAC.hexdigest(digest, AhoyEmail.secret_token, url)

      publish :click, url: params[:url]
      if ActiveSupport::SecurityUtils.secure_compare(user_signature, signature)
        redirect_to url
      else
        redirect_to AhoyEmail.invalid_redirect_url || main_app.root_url
      end
    end

    protected

    def set_message
      @message = AhoyEmail.message_model.where(token: params[:id]).first
    end

    def publish(name, event = {})
      AhoyEmail.subscribers.each do |subscriber|
        if subscriber.respond_to?(name)
          event[:message] = @message
          event[:controller] = self
          subscriber.send name, event
        end
      end
    end
  end
end
