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

    describe '#copy!' do
      let(:src_path) { '/var/data/elasticsearch/nodes/0/indices' }

      before do
        db.stubs(:dump_path).returns('/tmp/trigger/databases')
        db.stubs(:utility).with(:tar).returns('tar')
        db.stubs(:utility).with(:cat).returns('cat')
        db.path = '/var/data/elasticsearch'
      end

      context 'when the elasticsearch index directory exists' do
        before do
          File.expects(:exist?).in_sequence(s).with(src_path).returns(true)
        end

        context 'when a compressor is configured' do
          let(:pipeline) { mock }
          let(:compressor) { mock }

          before do
            model.stubs(:compressor).returns(compressor)
            compressor.stubs(:compress_with).yields('cmp_cmd', '.cmp_ext')
          end

          it 'packages the directory with compression' do
            Pipeline.expects(:new).in_sequence(s).returns(pipeline)

            pipeline.expects(:<<).in_sequence(s).with("tar -cf - #{src_path}")

            pipeline.expects(:<<).in_sequence(s).with('cmp_cmd')

            pipeline.expects(:<<).in_sequence(s).with(
              "cat > '/tmp/trigger/databases/Elasticsearch.tar.cmp_ext'"
            )

            pipeline.expects(:run).in_sequence(s)
            pipeline.expects(:success?).in_sequence(s).returns(true)

            db.send(:copy!)
          end
        end # context 'when a compressor is configured'

        context 'when no compressor is configured' do
          let(:pipeline) { mock }

          it 'packages the directory without compression' do
            Pipeline.expects(:new).in_sequence(s).returns(pipeline)

            pipeline.expects(:<<).in_sequence(s).with("tar -cf - #{src_path}")

            pipeline.expects(:<<).in_sequence(s).with(
              "cat > '/tmp/trigger/databases/Elasticsearch.tar'"
            )

            pipeline.expects(:run).in_sequence(s)
            pipeline.expects(:success?).in_sequence(s).returns(true)

            db.send(:copy!)
          end
        end # context 'when no compressor is configured'
      end # context 'when the elasticsearch index directory exists'

      context 'when the elasticsearch index directory does not exist' do
        it 'raises an error' do
          File.expects(:exist?).in_sequence(s).with(src_path).returns(false)
          expect do
            db.send(:copy!)
          end.to raise_error(Errors::Database::Elasticsearch::NotFoundError)
        end
      end # context 'when the elasticsearch index directory does not exist'
    end # describe '#copy!'
  end
end
