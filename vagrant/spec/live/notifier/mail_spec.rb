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
          notify_by Mail do |mail|
            mail.delivery_method      = :smtp
            mail.from                 = BackupSpec::LIVE['notifier']['mail']['from']
            mail.to                   = BackupSpec::LIVE['notifier']['mail']['to']
            mail.address              = BackupSpec::LIVE['notifier']['mail']['address']
            mail.port                 = BackupSpec::LIVE['notifier']['mail']['port']
            mail.user_name            = BackupSpec::LIVE['notifier']['mail']['user_name']
            mail.password             = BackupSpec::LIVE['notifier']['mail']['password']
            mail.authentication       = BackupSpec::LIVE['notifier']['mail']['authentication']
            mail.encryption           = BackupSpec::LIVE['notifier']['mail']['encryption']
            mail.openssl_verify_mode  = BackupSpec::LIVE['notifier']['mail']['openssl_verify_mode']
          end
        end
      EOS

      backup_perform :my_backup
    end

    it 'sends a warning email', :live do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          notify_by Mail do |mail|
            mail.delivery_method      = :smtp
            mail.from                 = BackupSpec::LIVE['notifier']['mail']['from']
            mail.to                   = BackupSpec::LIVE['notifier']['mail']['to']
            mail.address              = BackupSpec::LIVE['notifier']['mail']['address']
            mail.port                 = BackupSpec::LIVE['notifier']['mail']['port']
            mail.user_name            = BackupSpec::LIVE['notifier']['mail']['user_name']
            mail.password             = BackupSpec::LIVE['notifier']['mail']['password']
            mail.authentication       = BackupSpec::LIVE['notifier']['mail']['authentication']
            mail.encryption           = BackupSpec::LIVE['notifier']['mail']['encryption']
            mail.openssl_verify_mode  = BackupSpec::LIVE['notifier']['mail']['openssl_verify_mode']
          end

          # log a warning
          Backup::Logger.warn 'test warning'
        end
      EOS

      expect do
        backup_perform :my_backup
      end.to raise_error(SystemExit) {|exit| expect( exit.status ).to be(1) }
    end

    it 'sends a failure email (non-fatal)', :live do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          notify_by Mail do |mail|
            mail.delivery_method      = :smtp
            mail.from                 = BackupSpec::LIVE['notifier']['mail']['from']
            mail.to                   = BackupSpec::LIVE['notifier']['mail']['to']
            mail.address              = BackupSpec::LIVE['notifier']['mail']['address']
            mail.port                 = BackupSpec::LIVE['notifier']['mail']['port']
            mail.user_name            = BackupSpec::LIVE['notifier']['mail']['user_name']
            mail.password             = BackupSpec::LIVE['notifier']['mail']['password']
            mail.authentication       = BackupSpec::LIVE['notifier']['mail']['authentication']
            mail.encryption           = BackupSpec::LIVE['notifier']['mail']['encryption']
            mail.openssl_verify_mode  = BackupSpec::LIVE['notifier']['mail']['openssl_verify_mode']
          end

          archive :my_archive do |archive|
            archive.add '~/test_data/dir_a/file_a'
          end
        end
      EOS

      Archive.any_instance.should_receive(:perform!).
          and_raise('a non-fatal error')

      expect do
        backup_perform :my_backup
      end.to raise_error(SystemExit) {|exit| expect( exit.status ).to be(2) }
    end

    it 'sends a failure email (fatal)', :live do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          notify_by Mail do |mail|
            mail.delivery_method      = :smtp
            mail.from                 = BackupSpec::LIVE['notifier']['mail']['from']
            mail.to                   = BackupSpec::LIVE['notifier']['mail']['to']
            mail.address              = BackupSpec::LIVE['notifier']['mail']['address']
            mail.port                 = BackupSpec::LIVE['notifier']['mail']['port']
            mail.user_name            = BackupSpec::LIVE['notifier']['mail']['user_name']
            mail.password             = BackupSpec::LIVE['notifier']['mail']['password']
            mail.authentication       = BackupSpec::LIVE['notifier']['mail']['authentication']
            mail.encryption           = BackupSpec::LIVE['notifier']['mail']['encryption']
            mail.openssl_verify_mode  = BackupSpec::LIVE['notifier']['mail']['openssl_verify_mode']
          end

          archive :my_archive do |archive|
            archive.add '~/test_data/dir_a/file_a'
          end
        end
      EOS

      Archive.any_instance.should_receive(:perform!).
          and_raise(Exception.new('a fatal error'))

      expect do
        backup_perform :my_backup
      end.to raise_error(SystemExit) {|exit| expect( exit.status ).to be(3) }
    end

  end # context 'when using :smtp delivery method'

end
end
