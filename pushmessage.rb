require 'net/http'
require 'json'

class PushMessage

	load "./local_env.rb" if File.exists?("./local_env.rb")

	attr_accessor :recipient, :sendername, :message, :result, :db, :db_params, :response
 
	def initialize
		@recipient = recipient
		@sendername = sendername
		@message = message
		@result = result
		@response = response
		@db_params = {
			host: ENV['host'],
			port: ENV['port'],
			dbname: ENV['dbname'],
			user: ENV['user'],
			password: ENV['password']
		}
		
		@db = PG::Connection.new(db_params)
	end

	def notif_process(sendername, recipient, devicelist, message, resend_counter)
		response = send_notif(sendername, devicelist, message)
		result = verify_send_processed(response)
		p result
		db_entry_added = add_to_database(sendername, recipient, devicelist, message, result)
		statusmsg = check_status(result, devicelist)
	end

	def send_notif(sendername, devicelist, message)
		server_key = ENV['server_key']
		send_data = {
    	  "to" => devicelist,
	      "notification" => {
    	  "title" => "MinedMinds: " + sendername,
          "body" => message
     		 }     
	    }

   		uri = URI.parse("https://fcm.googleapis.com/fcm/send")
    	https = Net::HTTP.new(uri.host, uri.port)
    	https.use_ssl = true
    	https.verify_mode = OpenSSL::SSL::VERIFY_NONE

    	postmsg = Net::HTTP::Post.new(uri.path, initheader = {
      		'Content-Type' =>'application/json',
      		'Authorization' => 'key=' + server_key
    	})
    	postmsg.body = send_data.to_json

    	response = https.start do |https|
      		https.request(postmsg)
    	end
    end

#{"multicast_id"=>6276310525459562553, "success"=>0, "failure"=>1, "canonical_ids"=>0, "results"=>[{"error"=>"MismatchSenderId"}]}

    def verify_send_processed(response)
    	case response
    		when Net::HTTPSuccess   #200-series codes
    			result = JSON.parse(response.body)
    		when Net::HTTPRedirection #300-series codes  
    			result = JSON.parse(response.body)
    			#send_email_to_master to verify primary website to receive notifications hasn't changed
    		when Net::HTTPClientError #400-series codes
    			result = JSON.parse(response.body)
    			#send_email_to_master: authentication/authorization error
    		when Net::HTTPServerError  #500-series codes
    			#max_backoff_time = 64000
    			#if 
    			#notif_process(sendername, recipient, devicelist, message, resend_counter)
    			#honor Retry-After header in response
    			#wait 1 + random_number_milliseconds seconds and retry the request.
				#wait 2 + random_number_milliseconds seconds and retry the request.
				#wait 4 + random_number_milliseconds seconds and retry the request.
    		else
    			result = JSON.parse(response.body)
    	end

	end

	def add_to_database(sendername, recipient, devicelist, message, result)
		multicast_id = result["multicast_id"]
		canonical_id = result["canonical_ids"]
		if result["success"] == 1
			status = "success"
			messageid = result["results"][0]["message_id"]
		elsif result["failure"] == 1
			status = "failure"
			messageid = result["results"][0]["error"]
		end
		timestamp = Time.now.utc
		db.exec("INSERT INTO messages(recipient, sendername, message, messagestatus, messageid, timestamp, canonical_id, multicast_id) VALUES('#{recipient}','#{sendername}','#{message}','#{status}','#{messageid}','#{timestamp}','#{canonical_id}','#{multicast_id}')");
	end

#################################################################################
#  Function to test result codes to identify proper action                      #
#################################################################################

 	def check_status(result, devicelist)	
 		if result["success"] == 1
			statusmsg = "Push notification SUCCESSFUL"
			if result["results"][0].count > 1
				# send_email_to_master?: Notification processed but with warning on fcm_id
				statusmsg = "Push notification SUCCESSFUL, but Registration ID needs checked"
			end
		elsif result["failure"] == 1
			messageid = result["results"][0]["error"]
			if messageid == "Unavailable"
				statusmsg = "Push notification RETRYING"
				notif_process(sendername, recipient, devicelist, message)	
			elsif messageid == "InvalidRegistration"
				# send_email_to_master?: Individual needs to reinstall/reregister app on their device or dup entries may exist in db
				db.exec ("UPDATE accounts set fcm_id = null, device_type = null WHERE fcm_id = '" + devicelist + "'")
				statusmsg = "Push notification FAILED: Invalid Registration ID, app may have been reinstalled"
			elsif messageid == "NotRegistered"
				# send_email_to_master?: Individual removed app from their device
				db.exec ("UPDATE accounts set fcm_id = null, device_type = null WHERE fcm_id = '" + devicelist + "'")
				statusmsg = "Push notification FAILED: App was removed from target device"
			elsif messageid == "MissingRegistration"
				# send_email_to_master?: In theory, notif should not be permitted to individual without app installed
				statusmsg = "Push notification FAILED: No Device Registered"
			else
				# send_email_to_master?: Error recorded in db needs investigate and/or added here
				#Unregistered Device, Invalid Package Name, Mismatched Sender, Message Too Big (2048 for ios and topics;4096 otherwise)
				#Device Message Rate Exceeded, Invalid APNs credentials
				statusmsg = "Push notification FAILED: Reason needs investigated"
			end
		end
		statusmsg
	end

#################################################################################
#  Recommended function to send email notification when specific errors occur   #
#################################################################################

	def send_email_to_master

	end

#################################################################################
#  Function to process steps to send notification to multiple recipients        #
#################################################################################	

	def send_multi_process(sendername, recipient, message)
		devicelist = build_target_device_list(recipient)
		response = send_multi_notif(sendername, devicelist, message)
		result = verify_send_processed(response)
		db_entry_added = add_multi_to_database(sendername, recipient, devicelist, message, result)
		# statusmsg = check_status(result, devicelist)
	end

#################################################################################
#  Function to build array of fcm_ids for mentor, mentee, or all registered  #
#################################################################################

	def build_target_device_list(recipient)
		devicelist = []
		if recipient == "mentors"
			devices = db.exec("SELECT fcm_id FROM accounts WHERE mentor AND fcm_id IS NOT NULL")
			devices.each_row do |value, id|
				devicelist << value
			end
		elsif recipient == "mentees"
			devices = db.exec("SELECT fcm_id FROM accounts WHERE mentee AND fcm_id IS NOT NULL")
			devices.each_row do |value, id|
				devicelist << value
			end
		elsif recipient == "alldevices"
			devices = db.exec("SELECT fcm_id FROM accounts WHERE fcm_id IS NOT NULL")
			devices.each_row do |value, id|
				devicelist << value
			end
		end
		devicelist
	end

#################################################################################
#  Function to sent notification to multiple fcm_ids                         #
#################################################################################

    def send_multi_notif(sendername, devicelist, message)
    	server_key = ENV['server_key']
		send_data = {
    	  "registration_ids" => devicelist,
	      "notification" => {
    	  "title" => "MinedMinds: " + sendername,
          "body" => message
     		 }     
	    }

   		uri = URI.parse("https://fcm.googleapis.com/fcm/send")
    	https = Net::HTTP.new(uri.host, uri.port)
    	https.use_ssl = true
    	https.verify_mode = OpenSSL::SSL::VERIFY_NONE

    	postmsg = Net::HTTP::Post.new(uri.path, initheader = {
      		'Content-Type' =>'application/json',
      		'Authorization' => 'key=' + server_key
    	})
    	postmsg.body = send_data.to_json

    	response = https.start do |https|
      		https.request(postmsg)
    	end
    end

#################################################################################
#  Function to update db based on delivery status to multiple fcm_ids           #
#################################################################################

	def add_multi_to_database(sendername, recipient, devicelist, message, result)
		multicast_id = result["multicast_id"]
		canonical_id = result["canonical_ids"]

		devicelist.each_with_index do |devicemap, indx|
			device_owner = []
			owner = db.exec("SELECT email FROM accounts WHERE fcm_id = '#{devicemap}'")
			owner.each_row do |owner, id|
				device_owner << owner
			end
			
			if result["results"][indx].include?("message_id")
				status = "success"
				messageid = result["results"][indx]["message_id"]
			elsif result["results"][indx].include?("error")
				status = "failure"
				messageid = result["results"][indx]["error"]
			end
			timestamp = Time.now
			db.exec("INSERT INTO messages(recipient, sendername, message, messagestatus, messageid, timestamp, canonical_id, multicast_id, device_owner) VALUES('#{recipient}','#{sendername}','#{message}','#{status}','#{messageid}','#{timestamp}','#{canonical_id}','#{multicast_id}','#{device_owner}')");
		end

	end

#######################################################
#  Create fcm group - maximum number of members is 20 #
#######################################################
  	# def create_group(group_name, devicelist)
  	# 	server_key = ENV['server_key']
  	# 	registration_ids = devicelist
 		
   #   send_data = {
   #       "operation": "create",
   #       "notification_key_name": group_name,
   #       "registration_ids": devicelist
   #   }
   #   uri = URI.parse("https://android.googleapis.com/gcm/notification") 

   #   https = Net::HTTP.new(uri.host, uri.port)
   #   https.use_ssl = true
   #   https.verify_mode = OpenSSL::SSL::VERIFY_NONE

   #   postmsg = Net::HTTP::Post.new(uri.path, initheader = {
   #    		'Content-Type' =>'application/json',
   #    		'Authorization' => 'key=' + server_key
   #            'project_id' => '965549702365'
   #   })
   #   postmsg.body = send_data.to_json

   #   response = https.start do |https|
   #    		https.request(postmsg)
   #   end

   #   segment = JSON.parse(response.body)

   #end

# response = {"notification_key": "APA91bFnx1xa4rTy2Xs5eZlvTs1vIXpaeN2-gFb2TZDNrunbbpyMnRJfk7DUwVA0-EZ-1I7xL6x2vd9kVozo9bvGzPeC79ZrytHOA4m-YbIvKBBAtHwD0tU"}
# notification_key needs stored for sending to audience in future.  
# above key is for group called testGroup
# no way to query current group membership except through local records
# no way to delete group except through removing all members

#############################
#  Send to group responses  #
#############################

#total success
# {
#   "success": 2,
#   "failure": 0
# }

#partial success

# {
#   "success":1,
#   "failure":2,
#   "failed_registration_ids":[
#      "regId1",
#      "regId2"
#   ]
# }

######################################################
#  Add/remove member to fcm group, per documentation #
######################################################

#   def add_member(group_name, group_key, devicelist)
#     server_key = ENV['server_key']
#     registration_ids = devicelist
    
#     send_data = {
#         "operation": "add",    # replace "add" with "remove" to delete from group
#         "notification_key_name": group_name,
#         "notification_key": group_key,
#         "registration_ids": devicelist
#     }
#
#       uri = URI.parse("https://android.googleapis.com/gcm/googlenotification")  
#       https = Net::HTTP.new(uri.host, uri.port)
#       https.use_ssl = true
#       https.verify_mode = OpenSSL::SSL::VERIFY_NONE
#
#       postmsg = Net::HTTP::Post.new(uri.path, initheader = {
#           'Content-Type' =>'application/json',
#           'Authorization' => 'key=' + server_key,
#           'project_id' => '965549702365'
#       })
#       postmsg.body = send_data.to_json
#
#       response = https.start do |https|
#           https.request(postmsg)
#       end
#
#       segment = JSON.parse(response.body)
#
#   end


end