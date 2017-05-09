require 'sinatra'
require 'pg'
require_relative 'pushmessage.rb'
require_relative 'android_post_ops.rb'


	push = PushMessage.new

###################################################
#  Initialize Connection with AWS postgreSQL db   #
###################################################

	load "./local_env.rb" if File.exists?("./local_env.rb")

	
	db_params = {
		host: ENV['host'],
		port: ENV['port'],
		dbname: ENV['dbname'],
		user: ENV['user'],
		password: ENV['password']
	}

	db = PG::Connection.new(db_params)
	
	statusmsg = "Connected"
	
	get "/" do
		erb :selection, :locals => {:statusmsg => statusmsg}
	end

	get "/addcontacts" do
	   	erb :addcontacts	
	end

	post "/collect_data" do
		full_name = params[:full_name]
		email = params[:email]
		mentor = params[:mentor]
		mentee = params[:mentee]
		device_type = params[:device_type]
		fcm_id = params[:fcm_id]

		db.exec("INSERT INTO accounts(full_name, email, mentor, mentee, device_type, fcm_id) VALUES('#{full_name}','#{email}', '#{mentor}','#{mentee}','#{device_type}','#{fcm_id}')");

	
	# 	db.exec("INSERT INTO  public."user"(first_name, email, mentor, mentee, fcm_id) 
	# VALUES('#{full_name}','#{mentor}','#{mentee}','#{email}','#{fcm_id}')");

		redirect "/"
	end

	get "/list" do
   		mentorlist = db.exec("SELECT full_name, email, mentor, mentee, fcm_id FROM accounts");

   		erb :listcontacts, :locals => {:mentorlist => mentorlist}
	end

	get "/update_contact" do
		email = params[:email]		
		contact = db.exec("SELECT full_name, email, mentor, mentee, fcm_id, device_type FROM accounts WHERE email = '" + email + "'");

		erb :updatecontact, :locals => {:contact => contact[0]}
	end


	post "/update_contact" do
		full_name = params[:full_name]
		email = params[:email]
		mentor = params[:mentor]
		mentee = params[:mentee]
		device_type = params[:device_type]

		db.exec("UPDATE accounts set full_name = '#{full_name}', email = '#{email}', mentor = '#{mentor}', mentee = '#{mentee}', device_type = '#{device_type}' WHERE email = '" + email + "'");

		redirect "/"
	end

	get "/addmessage" do
		mentorlist = db.exec("SELECT full_name, email, mentor, mentee, fcm_id, device_type FROM accounts WHERE fcm_id IS NOT NULL");

		erb :addmessage, :locals => {:mentorlist => mentorlist}
	end

	post "/sendmessage" do
		recipient = params[:recipient].to_s
		sendername = params[:sendername].to_s
		message = params[:message].to_s
		
		devicelist = []		
		targetlist = db.exec("SELECT fcm_id FROM accounts WHERE email = '" + recipient + "'")
		targetlist.each_row do |value, id|
			devicelist << value
		end
		device = devicelist.join.to_s
		resend_counter = 0
		statusmsg = push.notif_process(sendername, recipient, device, message, resend_counter)

		redirect "/pushstatus?statusmsg=#{statusmsg}"                

	end

	get "/pushstatus" do
		statusmsg = params[:statusmsg]

		erb :pushstatus, :locals => {statusmsg: statusmsg}
	end

	get "/listmessages" do
		messagelist = db.exec("SELECT * FROM messages ORDER BY timestamp DESC")
		erb :listmessage, locals: {messagelist: messagelist}

	end

	get "/sendmulti" do
		erb :multimessage
	end

	post "/multimessage" do
		recipient = params[:recipient]
		message = params[:message]
		sendername = "Mentoring"

 		liststatus = push.send_multi_process(sendername, recipient, message)
 		redirect "/"
 	end

	post '/post_id' do
  		id_hash = {"email"=>params[:email], "pne_status"=>params[:pne_status], "fcm_id"=>params[:fcm_id]}
  		#email=params[:email]
  		#pne_status=params[:pne_status]
  		#fcm_id = params[:fcm_id]

  		check_db(id_hash)  # update/insert record with fcm_id
  		"Post successful - thanks for the info!"  # feedback for Xcode console (successful POST)
	end

