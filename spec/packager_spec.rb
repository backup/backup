# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe 'Backup::Packager' do
  let(:packager)  { Backup::Packager }

  describe '#package!' do
    let(:model)     { mock }
    let(:package)   { mock }
    let(:encryptor) { mock }
    let(:splitter)  { mock }
    let(:procedure) { mock }
    let(:s)         { sequence '' }

    it 'should setup variables and perform packaging procedures' do
      model.expects(:package).in_sequence(s).returns(package)
      model.expects(:encryptor).in_sequence(s).returns(encryptor)
      model.expects(:splitter).in_sequence(s).returns(splitter)

      Backup::Logger.expects(:message).in_sequence(s).with(
        'Packaging the backup files...'
      )
      packager.expects(:procedure).in_sequence(s).returns(procedure)
      procedure.expects(:call).in_sequence(s)
      Backup::Logger.expects(:message).in_sequence(s).with(
        'Packaging Complete!'
      )

      packager.package!(model)

      packager.instance_variable_get(:@package).should be(package)
      packager.instance_variable_get(:@encryptor).should be(encryptor)
      packager.instance_variable_get(:@splitter).should be(splitter)
    end
  end # describe '#package!'

  describe '#procedure' do

    module Fake
      def self.stack_trace
        @stack ||= []
      end
      class Encryptor
        def encrypt_with
          Fake.stack_trace << :encryptor_before
          yield 'encryption_command', '.enc'
          Fake.stack_trace << :encryptor_after
        end
      end
      class Splitter
        def split_with
          Fake.stack_trace << :splitter_before
          yield 'splitter_command'
          Fake.stack_trace << :splitter_after
        end
      end
      class Package
        attr_accessor :trigger, :extension
        def basename
          'base_filename.' + extension
        end
      end
    end

    let(:package)   { Fake::Package.new }
    let(:encryptor) { Fake::Encryptor.new }
    let(:splitter)  { Fake::Splitter.new }

    before do
      Fake.stack_trace.clear
      packager.expects(:utility).with(:tar).returns('tar')
      packager.instance_variable_set(:@package, package)
      package.trigger = 'model_trigger'
      package.extension = 'tar'
    end

    context 'when no encryptor or splitter are defined' do
      it 'should package the backup without encryption into a single file' do
        packager.instance_variable_set(:@encryptor, nil)
        packager.instance_variable_set(:@splitter,  nil)

        packager.expects(:run).with(
          "tar -cf - -C '#{ Backup::Config.tmp_path }' 'model_trigger'" +
          " > #{ File.join(Backup::Config.tmp_path, 'base_filename.tar') }"
        )
        packager.send(:procedure).call
      end
    end

    context 'when only an encryptor is configured' do
      it 'should package the backup with encryption' do
        packager.instance_variable_set(:@encryptor, encryptor)
        packager.instance_variable_set(:@splitter,  nil)

        packager.expects(:run).with do |command|
          Fake.stack_trace << :command_executed
          command.should ==
            "tar -cf - -C '#{ Backup::Config.tmp_path }' 'model_trigger'" +
            " | encryption_command" +
            " > #{ File.join(Backup::Config.tmp_path, 'base_filename.tar.enc') }"
        end
        packager.send(:procedure).call

        Fake.stack_trace.should == [
          :encryptor_before, :command_executed, :encryptor_after
        ]
      end
    end

    context 'when only a splitter is configured' do
      it 'should package the backup without encryption through the splitter' do
        packager.instance_variable_set(:@encryptor, nil)
        packager.instance_variable_set(:@splitter,  splitter)

        packager.expects(:run).with do |command|
          Fake.stack_trace << :command_executed
          command.should ==
            "tar -cf - -C '#{ Backup::Config.tmp_path }' 'model_trigger'" +
            " | splitter_command"
        end
        packager.send(:procedure).call

        Fake.stack_trace.should == [
          :splitter_before, :command_executed, :splitter_after
        ]
      end
    end

    context 'when both an encryptor and a splitter are configured' do
      it 'should package the backup with encryption through the splitter' do
        packager.instance_variable_set(:@encryptor, encryptor)
        packager.instance_variable_set(:@splitter,  splitter)

        packager.expects(:run).with do |command|
          Fake.stack_trace << :command_executed
          command.should ==
            "tar -cf - -C '#{ Backup::Config.tmp_path }' 'model_trigger'" +
            " | encryption_command | splitter_command"
        end
        packager.send(:procedure).call

        Fake.stack_trace.should == [
          :encryptor_before, :splitter_before,
          :command_executed,
          :splitter_after, :encryptor_after
        ]
        package.extension.should == 'tar.enc'
      end
    end

  end # describe '#procedure'

end
