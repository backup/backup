# encoding: utf-8

Backup::Configuration::S3.defaults do |s3|
  s3.access_key_id      = 'access_key_id'
  s3.secret_access_key  = 'secret_access_key'
  s3.region             = 'us-east-1'
end

# Backup::Configuration::Mail.defaults do |mail|
#   mail.from                 = 'my.sender.email@gmail.com'
#   mail.to                   = 'my.receiver.email@gmail.com'
#   mail.address              = 'smtp.gmail.com'
#   mail.port                 = 587
#   mail.domain               = 'your.host.name'
#   mail.user_name            = 'theuser'
#   mail.password             = 'secret'
#   mail.authentication       = 'plain'
#   mail.enable_starttls_auto = true
# end
#
# Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
#
#   use_adapter 'mysql' do |adapter|
#     adapter.database    = 'mydatabase'
#     adapter.user        = 'someuser'
#     adapter.password    = 'secret'
#     adapter.skip_tables = ['logs', 'profiles']
#     # adapter.only_tables = ['users', 'pirates']
#     adapter.additional_options = ['--single-transaction', '--quick']
#   end
#
#   archive 'all-logs' do |ar|
#     ar.add '/var/myuser/logs/errors/*'
#     ar.add '/var/myuser/logs/regular/*'
#   end
#
#   store_to 's3' do |storage|
#     storage.bucket = '/myapp/backups/mysql/'
#   end
#
#   compress_with 'gzip' do |compression|
#     compression.options = ['-C']
#   end
#
#   encrypt_with 'open_ssl' do |encryption|
#     encryption.password = 'secret'
#   end
#
#   cycle_backups do |backups|
#     backups.keep = 50
#   end
#
#   notifications do |notify|
#     notify.on_success = false
#     notify.on_error   = true
#   end
#
# end
