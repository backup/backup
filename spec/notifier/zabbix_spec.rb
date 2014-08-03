# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
  describe Notifier::Zabbix do
    let(:model) { Model.new(:test_trigger, 'test label') }
    let(:notifier) { Notifier::Zabbix.new(model) }

    before do
      Utilities.stubs(:utility).with(:zabbix_sender).returns('zabbix_sender')
      Config.stubs(:hostname).returns('zabbix.hostname')
    end

    it_behaves_like 'a class that includes Config::Helpers'
    it_behaves_like 'a subclass of Notifier::Base'

    describe '#initialize' do
      it 'provides default values' do
        expect( notifier.zabbix_host  ).to eq 'zabbix.hostname'
        expect( notifier.zabbix_port  ).to be 10051
        expect( notifier.service_name ).to eq 'Backup test_trigger'
        expect( notifier.service_host ).to eq 'zabbix.hostname'
        expect( notifier.item_key     ).to eq 'backup_status'

        expect( notifier.on_success     ).to be(true)
        expect( notifier.on_warning     ).to be(true)
        expect( notifier.on_failure     ).to be(true)
        expect( notifier.max_retries    ).to be(10)
        expect( notifier.retry_waitsec  ).to be(30)
      end

      it 'configures the notifier' do
        notifier = Notifier::Zabbix.new(model) do |zabbix|
          zabbix.zabbix_host  = 'my_zabbix_server'
          zabbix.zabbix_port  = 1234
          zabbix.service_name = 'my_service_name'
          zabbix.service_host = 'my_service_host'
          zabbix.item_key     = 'backup_status'

          zabbix.on_success    = false
          zabbix.on_warning    = false
          zabbix.on_failure    = false
          zabbix.max_retries   = 5
          zabbix.retry_waitsec = 10
        end

        expect( notifier.zabbix_host  ).to eq 'my_zabbix_server'
        expect( notifier.zabbix_port  ).to be 1234
        expect( notifier.service_name ).to eq 'my_service_name'
        expect( notifier.service_host ).to eq 'my_service_host'
        expect( notifier.item_key     ).to eq 'backup_status'
        expect( notifier.on_success     ).to be(false)
        expect( notifier.on_warning     ).to be(false)
        expect( notifier.on_failure     ).to be(false)
        expect( notifier.max_retries    ).to be(5)
        expect( notifier.retry_waitsec  ).to be(10)
      end

    end # describe '#initialize'

    describe '#notify!' do
      before do
        notifier.service_host = 'my.service.host'
        model.stubs(:duration).returns('12:34:56')
        notifier.stubs(:zabbix_port).returns(10051)
      end

      context 'when status is :success' do
        let(:zabbix_msg) {
          "my.service.host\tBackup test_trigger\t0\t" +
          "Completed Successfully in #{ model.duration }"
        }

        let(:zabbix_cmd) { 
          "zabbix_sender -z 'zabbix.hostname'" +
          " -p '#{ notifier.zabbix_port }'" +
          " -s #{ notifier.service_host }" +
          " -k #{notifier.item_key}" +
          " -o '#{ zabbix_msg }'"
        }

        before { model.stubs(:exit_status).returns(0) }

        it 'sends a Success message' do
          Utilities.expects(:run).with("echo '#{ zabbix_msg }' | #{ zabbix_cmd }")
          notifier.send(:notify!, :success)
        end
      end

      context 'when status is :warning' do
        let(:zabbix_msg) {
          "my.service.host\tBackup test_trigger\t1\t" +
          "Completed Successfully (with Warnings) in #{ model.duration }"
        }

        let(:zabbix_cmd) { 
          "zabbix_sender -z 'zabbix.hostname'" +
          " -p '#{ notifier.zabbix_port }'" +
          " -s #{ notifier.service_host }" +
          " -k #{ notifier.item_key }" +
          " -o '#{ zabbix_msg }'"
        }

        before { model.stubs(:exit_status).returns(1) }

        it 'sends a Warning message' do
          Utilities.expects(:run).with("echo '#{ zabbix_msg }' | #{ zabbix_cmd }")
          notifier.send(:notify!, :warning)
        end
      end

      context 'when status is :failure' do
        let(:zabbix_msg) {
          "my.service.host\tBackup test_trigger\t2\tFailed in #{ model.duration }"
        }

        let(:zabbix_cmd) { 
          "zabbix_sender -z 'zabbix.hostname'" +
          " -p '#{ notifier.zabbix_port }'" +
          " -s #{ notifier.service_host }" +
          " -k #{notifier.item_key}" +
          " -o '#{ zabbix_msg }'"
        }

        before { model.stubs(:exit_status).returns(2) }

        it 'sends a Failure message' do
          Utilities.expects(:run).with("echo '#{ zabbix_msg }' | #{ zabbix_cmd }")
          notifier.send(:notify!, :failure)
        end
      end
    end # describe '#notify!'

  end
end
