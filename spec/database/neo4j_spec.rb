# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
  describe Database::Neo4j do
    let(:model) { Model.new(:test_trigger, 'test label') }
    let(:db) { Database::Neo4j.new(model) }
    let(:s) { sequence '' }

    before do
      Database::Neo4j.any_instance.stubs(:utility).
          with('neo4j-backup').returns('neo4j-backup')
      Database::Neo4j.any_instance.stubs(:utility).
          with(:cat).returns('cat')
      Database::Neo4j.any_instance.stubs(:utility).
          with(:tar).returns('tar')
    end

    it_behaves_like 'a class that includes Config::Helpers'
    it_behaves_like 'a subclass of Database::Base'

    describe '#initialize' do
      it 'provides default values' do
        expect( db.database_id        ).to be_nil
        expect( db.host               ).to be_nil
        expect( db.port               ).to be_nil
      end

      it 'configures the database' do
        db = Database::Neo4j.new(model, :my_id) do |neo4j|
          neo4j.host               = 'my_host'
          neo4j.port               = 'my_port'
        end

        expect( db.host               ).to eq 'my_host'
        expect( db.port               ).to eq 'my_port'
      end
    end # describe '#initialize'

    describe '#perform!' do
      before do
        db.expects(:log!).in_sequence(s).with(:started)
        db.expects(:prepare!).in_sequence(s)
      end

      it 'dumps and packages the database' do
        db.expects(:dump!).in_sequence(s)
        db.expects(:package!).in_sequence(s)

        db.perform!
      end
    end # describe '#perform!'

    describe '#dump!' do
      before do
        db.stubs(:neo4j_backup).returns('neo4j_backup_command')
        db.stubs(:dump_path).returns('/tmp/trigger/databases')

        FileUtils.expects(:mkdir_p).in_sequence(s).
            with('/tmp/trigger/databases/Neo4j')
      end

      it 'runs neo4j_backup' do
        db.expects(:run).in_sequence(s).with('neo4j_backup_command')
        db.send(:dump!)
      end
    end # describe '#dump!'

    describe '#package!' do
      let(:pipeline) { mock }
      let(:compressor) { mock }

      before do
        db.stubs(:dump_path).returns('/tmp/trigger/databases')
      end

      context 'without a compressor' do
        it 'packages the dump without compression' do
          Pipeline.expects(:new).in_sequence(s).returns(pipeline)
          pipeline.expects(:<<).in_sequence(s).with(
            "tar -cf - -C '/tmp/trigger/databases' 'Neo4j'"
          )
          pipeline.expects(:<<).in_sequence(s).with(
            "cat > '/tmp/trigger/databases/Neo4j.tar'"
          )
          pipeline.expects(:run).in_sequence(s)
          pipeline.expects(:success?).in_sequence(s).returns(true)
          FileUtils.expects(:rm_rf).in_sequence(s).with(
            '/tmp/trigger/databases/Neo4j'
          )
          db.expects(:log!).in_sequence(s).with(:finished)

          db.send(:package!)
        end
      end # context 'without a compressor'

      context 'with a compressor' do
        before do
          model.stubs(:compressor).returns(compressor)
          compressor.stubs(:compress_with).yields('cmp_cmd', '.cmp_ext')
        end

        it 'packages the dump with compression' do
          Pipeline.expects(:new).in_sequence(s).returns(pipeline)
          pipeline.expects(:<<).in_sequence(s).with(
            "tar -cf - -C '/tmp/trigger/databases' 'Neo4j'"
          )
          pipeline.expects(:<<).in_sequence(s).with('cmp_cmd')
          pipeline.expects(:<<).in_sequence(s).with(
            "cat > '/tmp/trigger/databases/Neo4j.tar.cmp_ext'"
          )
          pipeline.expects(:run).in_sequence(s)
          pipeline.expects(:success?).in_sequence(s).returns(true)
          FileUtils.expects(:rm_rf).in_sequence(s).with(
            '/tmp/trigger/databases/Neo4j'
          )
          db.expects(:log!).in_sequence(s).with(:finished)

          db.send(:package!)
        end
      end # context 'with a compressor'

      context 'when the pipeline fails' do
        before do
          Pipeline.any_instance.stubs(:success?).returns(false)
          Pipeline.any_instance.stubs(:error_messages).returns('error messages')
        end

        it 'raises an error and does not remove the packaging path' do
          FileUtils.expects(:rm_rf).never
          db.expects(:log!).never

          expect do
            db.send(:package!)
          end.to raise_error(Database::Neo4j::Error) {|err|
            expect( err.message ).to eq(
              "Database::Neo4j::Error: Dump Failed!\n  error messages"
            )
          }
        end
      end # context 'when the pipeline fails'
    end # describe '#package!'

    describe '#neo4j_backup' do
      let(:option_methods) {%w[
        connectivity_options dump_packaging_path
      ]}

      it 'returns full neo4j_backup command built from all options' do
        option_methods.each {|name| db.stubs(name).returns(name) }
        expect( db.send(:neo4j_backup) ).to eq(
          "neo4j-backup connectivity_options -to 'dump_packaging_path'"
        )
      end

      it 'handles nil values from option methods' do
        option_methods.each {|name| db.stubs(name).returns(nil) }
        expect( db.send(:neo4j_backup) ).to eq "neo4j-backup  -to ''"
      end
    end # describe '#neo4j_backup'

    describe 'neo4j-backup option methods' do
      describe '#connectivity_options' do
        it 'returns connectivity arguments based on #host and #port' do
          expect( db.send(:connectivity_options) ).to eq ''

          db.host = 'my_host'
          expect( db.send(:connectivity_options) ).to eq(
            "-host 'my_host'"
          )

          db.port = 'my_port'
          expect( db.send(:connectivity_options) ).to eq(
            "-host 'my_host' -port 'my_port'"
          )

          db.host = nil
          expect( db.send(:connectivity_options) ).to eq(
            "-port 'my_port'"
          )
        end
      end # describe '#connectivity_options'
    end # describe 'neo4j_backup option methods'
  end
end
