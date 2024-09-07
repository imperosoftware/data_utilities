# frozen_string_literal: true

require_relative 'config/environment'
require_relative 'models'

@db_host = 'sm-uk-west-integration-platform.mariadb.database.azure.com'
@db_user = 'totesnotadmin@sm-uk-west-integration-platform'
@db_password = ENV.fetch('DBPASSWD')
@db_name = 'safeguardingmonitor_integration2'
@school_id = 20_996
@dump_files = []

def camel_to_snake_case(word)
  # Convert CamelCase to snake_case
  word.gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .tr('-', '_')
      .downcase
end

def pluralize(word)
  case word
  when 'security'
    'securities'
  when 'child'
    'children'
  when 'address'
    'addresses'
  when 'address'
    'addresses'
  when 'policy'
    'policies'
  when 'access'
    'accesses'
  when 'agency'
    'agencies'
  when 'person'
    'people'
  when 'reply'
    'replies'
  when 'status'
    'statuses'
  else
    word + 's'
  end
end

def convert_and_pluralize(word)
  snake_case_word = camel_to_snake_case(word)
  parts = snake_case_word.split('_')
  parts[-1] = pluralize(parts[-1])
  parts.join('_')
end

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
    system dump_cmd(table_name)

    if $?.exitstatus == 0
      @dump_files << "restore_#{table_name}.sql"
      puts "Successful dump! Data saved to restore_#{table_name}.sql"
    else
      puts '*** Failed dump! Check your credentials'
    end
  end
end

def dump_school_table
  cmd = %(mysqldump -h #{@db_host} --ssl_ca=/usr/local/share/ca-certificates/azure_mariadb_ca.pem -u #{@db_user} -p#{@db_password} --no-create-info #{@db_name} schools --where="id=#{@school_id}" > restore_school.sql )
  system(cmd)

  if $?.exitstatus == 0
    @dump_files << 'restore_school.sql'
    puts 'Successful dump! Data saved to restore_school.sql'
  else
    puts '*** Failed dump! Check your credentials'
  end
end

def dump_group_members
  dump_file = 'restore_group_members.sql'
  cmd = %(mysqldump -h #{@db_host} --ssl_ca=/usr/local/share/ca-certificates/azure_mariadb_ca.pem -u #{@db_user} -p#{@db_password} --no-create-info --lock-all-tables #{@db_name} group_members --where="group_id IN (SELECT id FROM groups WHERE school_id=#{@school_id})" > #{dump_file} )
  system(cmd)

  if $?.exitstatus == 0
    @dump_files << dump_file
    puts 'Successful dump! Data saved to restore_school.sql'
  else
    puts '*** Failed dump! Check your credentials'
  end
end

##### main run #####

dump_core_tables
dump_school_table
dump_group_members

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
puts 'now deleting temporary files...'
@dump_files.each { |f| File.delete(f) }
