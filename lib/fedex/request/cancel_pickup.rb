require 'fedex/request/base'

module Fedex
  module Request
    class CancelPickup < Base

      attr_reader :schedule_date, :pickup_confirmation_number, :location, :carrier_code, :remarks

      def initialize(credentials, options={})
        requires!(options, :schedule_date, :pickup_confirmation_number, :location, :carrier_code)

        # Implemented for fedex user id and app name storing starts
        @user = options[:user_id] || nil
        @app = options[:app] || nil
        # Implemented for fedex user id and app name storing ends

        @schedule_date  = options[:schedule_date]
        @pickup_confirmation_number  = options[:pickup_confirmation_number]
        @location  = options[:location]
        @carrier_code = options[:carrier_code]
        @remarks = options[:remarks]
        @credentials  = credentials
      end

      def process_request
        api_response = self.class.post(api_url, :body => build_xml)
        @fedex_request = FedexRequest.create(request: build_xml, response: api_response, request_type: "Cancel Pickup", user_id: @user, app: @app)
        puts api_response if @debug == true
        response = parse_response(api_response)
        if success?(response)
          success_response(api_response, response)
        else
          failure_response(api_response, response)
        end
      end

      private

      # Build xml Fedex Web Service request
      def build_xml
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.CancelPickupRequest(:xmlns => "http://fedex.com/ws/pickup/v#{service[:version]}"){
            add_web_authentication_detail(xml)
            add_client_detail(xml)
            add_version(xml)
            xml.CarrierCode @carrier_code || "FDXE"
            xml.PickupConfirmationNumber @pickup_confirmation_number
            xml.ScheduledDate @schedule_date
            xml.Location @location
            xml.Remarks @remarks if @remarks
          }
        end
        builder.doc.root.to_xml
      end

      def service
        { :id => 'disp', :version => Fedex::CANCEL_PICKUP_API_VERSION }
      end

      # Callback used after a failed pickup response.
      def failure_response(api_response, response)
        error_message = if response[:cancel_pickup_reply]
          [response[:cancel_pickup_reply][:notifications]].flatten.first[:message]
        else
          "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n--#{Array(api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"]).join("\n--")}"
        end rescue $1
        raise RateError, error_message
      end

      # Callback used after a successful pickup response.
      def success_response(api_response, response)
        @response_details = response[:cancel_pickup_reply]
      end

      # Successful request
      def success?(response)
        response[:cancel_pickup_reply] &&
          %w{SUCCESS WARNING NOTE}.include?(response[:cancel_pickup_reply][:highest_severity])
      end
    end
  end
end
