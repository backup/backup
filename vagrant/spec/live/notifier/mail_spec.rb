# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

# To run these tests, you need to setup your Mail credentials in
#   /vagrant/spec/live.yml
#
module Backup
describe Notifier::Mail,
    :if => BackupSpec::LIVE['notifier']['mail']['specs_enabled'] == true do

  # These tests send actual emails. Check your mail to verify success.
  context 'when using :smtp delivery method' do

    it 'sends a success email', :live do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          config = BackupSpec::LIVE['notifier']['mail']
          notify_by Mail do |mail|
            mail.delivery_method      = :smtp
            mail.from                 = config['from']
            mail.to                   = config['to']
            mail.address              = config['address']
            mail.port                 = config['port']
            mail.user_name            = config['user_name']
            mail.password             = config['password']
            mail.authentication       = config['authentication']
            mail.encryption           = config['encryption']
            mail.openssl_verify_mode  = config['openssl_verify_mode']
          end
        end
      EOS

      backup_perform :my_backup
    end

    it 'sends a warning email', :live do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          config = BackupSpec::LIVE['notifier']['mail']
          notify_by Mail do |mail|
            mail.delivery_method      = :smtp
            mail.from                 = config['from']
            mail.to                   = config['to']
            mail.address              = config['address']
            mail.port                 = config['port']
            mail.user_name            = config['user_name']
            mail.password             = config['password']
            mail.authentication       = config['authentication']
            mail.encryption           = config['encryption']
            mail.openssl_verify_mode  = config['openssl_verify_mode']
          end

          # log a warning
          Backup::Logger.warn 'test warning'
        end
      EOS

      backup_perform :my_backup, :exit_status => 1
    end

    it 'sends a failure email (non-fatal)', :live do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          config = BackupSpec::LIVE['notifier']['mail']
          notify_by Mail do |mail|
            mail.delivery_method      = :smtp
            mail.from                 = config['from']
            mail.to                   = config['to']
            mail.address              = config['address']
            mail.port                 = config['port']
            mail.user_name            = config['user_name']
            mail.password             = config['password']
            mail.authentication       = config['authentication']
            mail.encryption           = config['encryption']
            mail.openssl_verify_mode  = config['openssl_verify_mode']
          end

          archive :my_archive do |archive|
            archive.add '~/test_data/dir_a/file_a'
          end
        end
      EOS

      Archive.any_instance.should_receive(:perform!).
          and_raise('a non-fatal error')

      backup_perform :my_backup, :exit_status => 2
    end

    it 'sends a failure email (fatal)', :live do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          config = BackupSpec::LIVE['notifier']['mail']
          notify_by Mail do |mail|
            mail.delivery_method      = :smtp
            mail.from                 = config['from']
            mail.to                   = config['to']
            mail.address              = config['address']
            mail.port                 = config['port']
            mail.user_name            = config['user_name']
            mail.password             = config['password']
            mail.authentication       = config['authentication']
            mail.encryption           = config['encryption']
            mail.openssl_verify_mode  = config['openssl_verify_mode']
          end

          archive :my_archive do |archive|
            archive.add '~/test_data/dir_a/file_a'
          end
        end
      EOS

      Archive.any_instance.should_receive(:perform!).
          and_raise(Exception.new('a fatal error'))

      backup_perform :my_backup, :exit_status => 3
    end

  end # context 'when using :smtp delivery method'

end
end
