# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
  describe Database::Elasticsearch do
    let(:model) { Model.new(:test_trigger, 'test label') }
    let(:db) { Database::Elasticsearch.new(model) }
    let(:s) { sequence '' }

    it_behaves_like 'a class that includes Configuration::Helpers'
    it_behaves_like 'a subclass of Database::Base'

    describe '#initialize' do
      it 'provides default values' do
        expect( db.path         ).to be_nil
        expect( db.index        ).to eq :all
        expect( db.invoke_flush ).to be_nil
        expect( db.invoke_close ).to be_nil
        expect( db.host         ).to eq 'localhost'
        expect( db.port         ).to eq 9200
      end
    end # describe '#initialize'

    describe '#perform!' do
      before do
        db.expects(:log!).in_sequence(s).with(:started)
        db.expects(:prepare!).in_sequence(s)
      end

      specify 'when #invoke_flush is true' do
        db.invoke_flush = true

        db.expects(:invoke_flush!).in_sequence(s)
        db.expects(:copy!).in_sequence(s)
        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end

      specify 'when #invoke_flush is false' do
        db.expects(:invoke_flush!).never
        db.expects(:copy!).in_sequence(s)
        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end

      specify 'when #invoke_close is true and #index is :all' do
        db.invoke_close = true

        db.expects(:invoke_close!).never
        db.expects(:copy!).in_sequence(s)
        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end

      specify 'when #invoke_close is true and #index is "test"' do
        db.index = "test"
        db.invoke_close = true

        db.expects(:invoke_close!).in_sequence(s)
        db.expects(:copy!).in_sequence(s)
        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end

      specify 'when #invoke_close is false' do
        db.expects(:invoke_close!).never
        db.expects(:copy!).in_sequence(s)
        db.expects(:log!).in_sequence(s).with(:finished)

        db.perform!
      end
    end # describe '#perform!'

    describe '#invoke_flush!' do
      let(:api_response) do
        Struct.new(:code, :message, :body)
      end
      let(:api_response_ok) { api_response.new('200', 'OK', '') }
      let(:api_response_not_found) { api_response.new('404', 'Not Found', '') }

      specify 'when response is OK' do
        db.stubs(:api_request).returns(api_response_ok)
        db.send(:invoke_flush!)
      end

      specify 'when response is not OK' do
        db.stubs(:api_request).returns(api_response_not_found)
        expect do
          db.send(:invoke_flush!)
        end.to raise_error(Errors::Database::Elasticsearch::QueryError) {|err|
          expect( err.message ).to match(/Response code was: 404/)
        }
      end
    end # describe '#invoke_flush!'

    describe '#invoke_close!' do
      let(:api_response) do
        Struct.new(:code, :message, :body)
      end
      let(:api_response_ok) { api_response.new('200', 'OK', '') }
      let(:api_response_not_found) { api_response.new('404', 'Not Found', '') }

      specify 'when response is OK' do
        db.stubs(:api_request).returns(api_response_ok)
        db.send(:invoke_close!)
      end

      specify 'when response is not OK' do
        db.stubs(:api_request).returns(api_response_not_found)
        expect do
          db.send(:invoke_close!)
        end.to raise_error(Errors::Database::Elasticsearch::QueryError) {|err|
          expect( err.message ).to match(/Response code was: 404/)
        }
      end
    end # describe '#invoke_close!'

#    describe '#copy!' do
#      before do
#        db.stubs(:dump_path).returns('/tmp/trigger/databases')
#        db.path = '/var/lib/redis'
#      end
#
#      context 'when the redis dump file exists' do
#        before do
#          File.expects(:exist?).in_sequence(s).with(
#                                                    '/var/lib/redis/dump.rdb'
#                                                    ).returns(true)
#        end
#
#        context 'when a compressor is configured' do
#          let(:compressor) { mock }
#
#          before do
#            model.stubs(:compressor).returns(compressor)
#            compressor.stubs(:compress_with).yields('cmp_cmd', '.cmp_ext')
#          end
#
#          it 'should copy the redis dump file with compression' do
#            db.expects(:run).in_sequence(s).with(
#                                                 "cmp_cmd -c '/var/lib/redis/dump.rdb' > " +
#                                                 "'/tmp/trigger/databases/Redis.rdb.cmp_ext'"
#                                                 )
#            FileUtils.expects(:cp).never
#
#            db.send(:copy!)
#          end
#        end # context 'when a compressor is configured'
#
#        context 'when no compressor is configured' do
#          it 'should copy the redis dump file without compression' do
#            FileUtils.expects(:cp).in_sequence(s).with(
#                                                       '/var/lib/redis/dump.rdb', '/tmp/trigger/databases/Redis.rdb'
#                                                       )
#            db.expects(:run).never
#
#            db.send(:copy!)
#          end
#        end # context 'when no compressor is configured'
#
#      end # context 'when the redis dump file exists'
#
#      context 'when the redis dump file does not exist' do
#        it 'raises an error' do
#          File.expects(:exist?).in_sequence(s).with(
#                                                    '/var/lib/redis/dump.rdb'
#                                                    ).returns(false)
#
#          expect do
#            db.send(:copy!)
#          end.to raise_error(Errors::Database::Redis::NotFoundError)
#        end
#      end # context 'when the redis dump file does not exist'
#
#    end # describe '#copy!'
#
#    describe '#redis_save_cmd' do
#      let(:option_methods) {%w[
#      redis_cli_utility password_option connectivity_options user_options
#    ]}
#
#      it 'returns full redis-cli command built from all options' do
#        option_methods.each {|name| db.stubs(name).returns(name) }
#        expect( db.send(:redis_save_cmd) ).to eq(
#                                                 option_methods.join(' ') + ' SAVE'
#                                                 )
#      end
#
#      it 'handles nil values from option methods' do
#        option_methods.each {|name| db.stubs(name).returns(nil) }
#        expect( db.send(:redis_save_cmd) ).to eq(
#                                                 (' ' * (option_methods.count - 1)) + ' SAVE'
#                                                 )
#      end
#    end # describe '#redis_save_cmd'
#
#    describe 'redis_save_cmd option methods' do
#
#      describe '#password_option' do
#        it 'returns argument if specified' do
#          expect( db.send(:password_option) ).to be_nil
#
#          db.password = 'my_password'
#          expect( db.send(:password_option) ).to eq "-a 'my_password'"
#        end
#      end # describe '#password_option'
#
#      describe '#connectivity_options' do
#        it 'returns only the socket argument if #socket specified' do
#          db.host = 'my_host'
#          db.port = 'my_port'
#          db.socket = 'my_socket'
#          expect( db.send(:connectivity_options) ).to eq(
#                                                         "-s 'my_socket'"
#                                                         )
#        end
#
#        it 'returns host and port arguments if specified' do
#          expect( db.send(:connectivity_options) ).to eq ''
#
#          db.host = 'my_host'
#          expect( db.send(:connectivity_options) ).to eq(
#                                                         "-h 'my_host'"
#                                                         )
#
#          db.port = 'my_port'
#          expect( db.send(:connectivity_options) ).to eq(
#                                                         "-h 'my_host' -p 'my_port'"
#                                                         )
#
#          db.host = nil
#          expect( db.send(:connectivity_options) ).to eq(
#                                                         "-p 'my_port'"
#                                                         )
#        end
#      end # describe '#connectivity_options'
#
#      describe '#user_options' do
#        it 'returns arguments for any #additional_options specified' do
#          expect( db.send(:user_options) ).to eq ''
#
#          db.additional_options = ['--opt1', '--opt2']
#          expect( db.send(:user_options) ).to eq '--opt1 --opt2'
#
#          db.additional_options = '--opta --optb'
#          expect( db.send(:user_options) ).to eq '--opta --optb'
#        end
#      end # describe '#user_options'
#
#    end # describe 'redis_save_cmd option methods'

  end
end
