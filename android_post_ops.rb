require 'pg'
load "./local_env.rb" if File.exists?("./local_env.rb")

# Method to open a connection to the PostgreSQL database
def open_db()
  begin  # connect to the database
    db_params = {
          host: ENV['host'],
          port: ENV['port'],
          dbname: ENV['dbname'],
          user: ENV['user'],
          password: ENV['password']
        }
    conn = PG::Connection.new(db_params)
  rescue PG::Error => e
    puts 'Exception occurred'
    puts e.message
  end
end

# Method to insert record for device into PostgreSQL db
def write_db(id_hash)
  v_email = id_hash["email"]  # prepare data from id_hash for database insert
  v_pne_status = id_hash["pne_status"]
  v_fcm_id = id_hash["fcm_id"]
  begin
    conn = open_db() # open database for updating
    max_id = conn.exec("select max(id) from accounts")[0]  # determine current max index (id) in details table
    max_id["max"] == nil ? v_id = 1 : v_id = max_id["max"].to_i + 1  # set index variable based on current max index value
    conn.prepare('q_statement',
                 "insert into accounts (id, email, pne_status, fcm_id)
                  values($1, $2, $3, $4)")  # bind parameters
    conn.exec_prepared('q_statement', [v_id, v_email, v_pne_status, v_fcm_id])
    conn.exec("deallocate q_statement")
  rescue PG::Error => e
    puts 'Exception occurred'
    puts e.message
  ensure
    conn.close if conn
  end
end

# Method to update existing record for device in PostgreSQL db
def update_db(id_hash)
  email = id_hash["email"]  # prepare email address for db record selection
  # fcm_id = id_hash["fcm_id"]  # prepare Firebase token for record update
  # pne_status = id_hash["pne_status"]  # prepare push notif flag for record update
  begin
    conn = open_db() # open database for updating
    id_hash.each do |column, value|  # iterate through entry_hash for each column/value pair
      unless column == "id"  # we do NOT want to update the id
        query = "update accounts set " + column + " = $2 where email = $1"  # can't use column name as bind parameter
        conn.prepare('q_statement', query)
        rs = conn.exec_prepared('q_statement', [email, value])
        conn.exec("deallocate q_statement")
      end
    end
    # query = "update accounts set fcm_id = $2 where email = $1"
    # conn.prepare('q_statement', query)
    # rs = conn.exec_prepared('q_statement', [email, fcm_id])
    # conn.exec("deallocate q_statement")
  rescue PG::Error => e
    puts 'Exception occurred'
    puts e.message
  ensure
    conn.close if conn
  end
end

# Method to determine whether to insert or update record
def check_db(id_hash)
  email = id_hash["email"]  # prepare email address for database query
  begin
    conn = open_db() # open database for updating
    query = "select email from accounts where email = $1"
    conn.prepare('q_statement', query)
    rs = conn.exec_prepared('q_statement', [email])
    conn.exec("deallocate q_statement")
    rs.to_a == [] ? write_db(id_hash) : update_db(id_hash)
  rescue PG::Error => e
    puts 'Exception occurred'
    puts e.message
  ensure
    conn.close if conn
  end
end

# Method to return all records from PostgreSQL db for reviewing entries via Heroku
def get_data()
  begin
    conn = open_db() # open database for updating
    query = "select * from accounts"
    conn.prepare('q_statement', query)
    rs = conn.exec_prepared('q_statement')
    conn.exec("deallocate q_statement")
    rs.to_a == [] ? (return []) : (return rs.to_a)
  rescue PG::Error => e
    puts 'Exception occurred'
    puts e.message
  ensure
    conn.close if conn
  end
end

#-----------------
# Sandbox testing
#-----------------

#-------------------------------------------
# 1 - Database insert tests
#-------------------------------------------

# id_hash_1 = {"email"=>"insert_test_1@test.com", "pne_status"=>"1", "fcm_id"=>"b1_D2qKfFdM:APA91bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"}
# write_db(id_hash_1)

# id_hash_2 = {"email"=>"insert_test_2@test.com", "pne_status"=>"0", "fcm_id"=>"d7_F8mLmIqA:JDM72bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-m"}
# write_db(id_hash_2)

# id_hash_3 = {"email"=>"insert_test_3@test.com"}
# write_db(id_hash_3)

#-------------------------------------------
# 2 - Database update test
#-------------------------------------------

# update_1 = {"email"=>"mag@abc.com", "pne_status"=>"0", "fcm_id"=>"m7_F8mLbKeD:WKD91bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"}
# update_db(update_1)

# update_2 = {"email"=>"mig@ghi.com", "pne_status"=>"1", "fcm_id"=>"s4_T2kNaIwP:ENG16bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"}
# update_db(update_2)

#-------------------------------------------
# 3 - Database check tests (insert/update)
#-------------------------------------------

# Test for exisiting record, no Firebase token
# record_1 = {"email"=>"mug@mno.com", "pne_status"=>"1", "fcm_id"=>"t0_H9aBlEpM:SDR57bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"}
# check_db(record_1)
# Output of result using "p rs.to_a":
# [{"email"=>"mug@mno.com"}]

# Test for existing record, existing Firebase token
# record_2 = {"email"=>"mag@abc.com", "pne_status"=>"1", "fcm_id"=>"m8_F8mLbKeD:WKD91bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"}
# check_db(record_2)
# Output of result using "p rs.to_a":
# [{"email"=>"mag@abc.com"}]

# Test for no record
# record_3 = {"email"=>"new@user.com", "pne_status"=>"0", "fcm_id"=>"r9_G5qPaCfW:LWK72bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"}
# check_db(record_3)
# Output of result using "p rs.to_a":
# []

#-------------------------------------------
# 4 - Get database records
#-------------------------------------------

# p get_data()
# Output:
# [{"id"=>"2", "email"=>"meg@def.com", "pne_status"=>"0", "fcm_id"=>"c0_N1zLfFdM:APA32bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR78WC1-8GH1cgrCdjDIt8BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-t"},
#  {"id"=>"4", "email"=>"mog@jkl.com", "pne_status"=>"1", "fcm_id"=>"d3_B4mJfFdM:APA32bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR78WC1-8GH1cgrCdjDIt8BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8bke-m"},
#  {"id"=>"6", "email"=>"insert_test_1@test.com", "pne_status"=>"1", "fcm_id"=>"b1_D2qKfFdM:APA91bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"},
#  {"id"=>"7", "email"=>"insert_test_2@test.com", "pne_status"=>"0", "fcm_id"=>"d7_F8mLmIqA:JDM72bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-m"},
#  {"id"=>"8", "email"=>"insert_test_3@test.com", "pne_status"=>nil, "fcm_id"=>nil},
#  {"id"=>"3", "email"=>"mig@ghi.com", "pne_status"=>"1", "fcm_id"=>"s4_T2kNaIwP:ENG16bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"},
#  {"id"=>"5", "email"=>"mug@mno.com", "pne_status"=>"1", "fcm_id"=>"t0_H9aBlEpM:SDR57bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"},
#  {"id"=>"1", "email"=>"mag@abc.com", "pne_status"=>"1", "fcm_id"=>"m8_F8mLbKeD:WKD91bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"},
#  {"id"=>"9", "email"=>"new@user.com", "pne_status"=>"0", "fcm_id"=>"r9_G5qPaCfW:LWK72bGUvD0qnBQ9hf4NtJHkuWBBvzHM3mYddRunvGOwgdCLEu0h3EQJF_f9mND7WkxUBR76WC1-8GH1cgrCdjDIt7BzHu9qx7_FLiQSpSvwfzxXfsqaeiqh3r7y30IVwRP5ic8fjg-y"}
# ]