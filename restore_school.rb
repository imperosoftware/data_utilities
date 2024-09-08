# frozen_string_literal: true

require_relative 'config/environment'
require_relative 'models'

@db_host = 'sm-uk-west-integration-platform.mariadb.database.azure.com'
@db_user = 'totesnotadmin@sm-uk-west-integration-platform'
@db_password = ENV.fetch('DBPASSWD')
@db_name = 'safeguardingmonitor_integration2'
@school_id = 20_996
@dump_files = []

# Method to find all dependent associations
def dependent_associations(model)
  model.reflect_on_all_associations.select do |association|
    association.options[:dependent].present?
  end
end

# Method to find all foreign keys of a model
def foreign_keys(model)
  model.reflect_on_all_associations(:belongs_to).map do |association|
    association.foreign_key
  end
end

def dump_cmd(db_table)
  %(mysqldump -h #{@db_host} --ssl_ca=/usr/local/share/ca-certificates/azure_mariadb_ca.pem -u #{@db_user} -p#{@db_password} --no-create-info #{@db_name} #{db_table} --where="school_id=#{@school_id}" > restore_#{db_table}.sql )
end

def dump_core_tables
  @models.each do |model|
    table_name = model.tableize
    dump_file = "restore_#{table_name}.sql"
    system dump_cmd(table_name)
    process_result($?.exitstatus, dump_file)
  end
end

def process_result(status, dump_file)
  if status == 0
    @dump_files << dump_file
    puts "Successful dump! Data saved to #{dump_file}"
  else
    puts '*** Failed dump! Check your credentials'
  end
end

def dump_school_table
  cmd = %(mysqldump -h #{@db_host} --ssl_ca=/usr/local/share/ca-certificates/azure_mariadb_ca.pem -u #{@db_user} -p#{@db_password} --no-create-info #{@db_name} schools --where="id=#{@school_id}" > restore_school.sql )
  system(cmd)
  process_result($?.exitstatus, 'restore_school.sql')
end

def dump_group_members
  dump_file = 'restore_group_members.sql'
  cmd = %(mysqldump -h #{@db_host} --ssl_ca=/usr/local/share/ca-certificates/azure_mariadb_ca.pem -u #{@db_user} -p#{@db_password} --no-create-info --lock-all-tables #{@db_name} group_members --where="group_id IN (SELECT id FROM groups WHERE school_id=#{@school_id})" > #{dump_file} )
  system(cmd)
  process_result($?.exitstatus, dump_file)
end

def dump_group_keyword_lists
  dump_file = 'restore_group_keyword_lists.sql'
  cmd = %(mysqldump -h #{@db_host} --ssl_ca=/usr/local/share/ca-certificates/azure_mariadb_ca.pem -u #{@db_user} -p#{@db_password} --no-create-info --lock-all-tables #{@db_name} group_keyword_lists --where="group_id IN (SELECT id FROM groups WHERE school_id=#{@school_id})" > #{dump_file} )
  system(cmd)
  process_result($?.exitstatus, dump_file)
end

def dump_children
  dump_file = 'restore_children.sql'
  sql = "SELECT gm.memberable_id FROM schools s JOIN groups g ON s.id = g.school_id JOIN group_members gm ON g.id = gm.group_id WHERE s.id = #{@school_id} AND gm.memberable_type = 'Child'"

  cmd = %(mysqldump -h #{@db_host} --ssl_ca=/usr/local/share/ca-certificates/azure_mariadb_ca.pem -u #{@db_user} -p#{@db_password} --no-create-info --lock-all-tables #{@db_name} children --where="id IN (#{sql})" > #{dump_file} )
  system(cmd)
  process_result($?.exitstatus, dump_file)
end

def dump_users
  dump_file = 'restore_users.sql'
  sql = "SELECT gm.memberable_id FROM schools s JOIN groups g ON s.id = g.school_id JOIN group_members gm ON g.id = gm.group_id WHERE s.id = #{@school_id} AND gm.memberable_type = 'User'"

  cmd = %(mysqldump -h #{@db_host} --ssl_ca=/usr/local/share/ca-certificates/azure_mariadb_ca.pem -u #{@db_user} -p#{@db_password} --no-create-info --lock-all-tables #{@db_name} users --where="id IN (#{sql})" > #{dump_file} )
  system(cmd)
  process_result($?.exitstatus, dump_file)
end

def dump_permissions_user_groups
  dump_file = 'restore_permissions_user_groups.sql'
  sql = "SELECT id FROM user_groups WHERE school_id = #{@school_id}"
  cmd = %(mysqldump -h #{@db_host} --ssl_ca=/usr/local/share/ca-certificates/azure_mariadb_ca.pem -u #{@db_user} -p#{@db_password} --no-create-info --lock-all-tables #{@db_name} permissions_user_groups --where="user_group_id IN (#{sql})" > #{dump_file} )
  system(cmd)
  process_result($?.exitstatus, dump_file)
end

##### main run #####

dump_core_tables
dump_school_table
dump_group_members
dump_children
dump_users
dump_permissions_user_groups

output_file = 'total_dump.sql'

File.open(output_file, 'w') do |outfile|
  @dump_files.each do |file|
    File.open(file, 'r') do |infile|
      outfile.write(infile.read)
      outfile.write("\n")
    end
  end
end

puts "-----> Dump file #{output_file} has been created."
print 'now deleting temporary files '
@dump_files.each do |f|
  print '.'
  File.delete(f)
end
puts 'Done!'
