# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'

describe Campfire do

  let(:room) do
    Room.new('room_id', 'subdomain', 'token')
  end

  it do
    room.token.should       == 'token'
    room.subdomain.should        == 'subdomain'
    room.room_id.should == 'room_id'
  end

end
