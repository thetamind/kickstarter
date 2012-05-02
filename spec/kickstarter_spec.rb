require 'webmock/rspec'
require 'kickstarter'

describe Kickstarter do
  it "should list all categories" do
    WebMock.enable!
    stub_request(:get, Kickstarter::BASE_URL).
      to_return( File.new("./spec/discover.txt").read )

    categories = {}
    Kickstarter.categories do |name, path|
      categories[name] = path
    end
    categories.length.should > 0

    WebMock.should have_requested(:get, Kickstarter::BASE_URL)
  end
  
  PPP = 15 # projects per page
  
  it "should list 1 page from recommended projects" do
    WebMock.disable!
    projects = Kickstarter.by_list(:recommended, :pages => 1)
    projects.count.should == PPP
  end
  
  it "should list 2 pages from recommended projects" do
    WebMock.disable!
    projects = Kickstarter.by_list(:recommended, :pages => 2)
    projects.count.should == 2 * PPP
  end
end
