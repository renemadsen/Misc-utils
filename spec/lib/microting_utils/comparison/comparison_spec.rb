#require '/spec/spec_helper'

#$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'lib')

require "#{File.join(File.dirname(__FILE__), '..', '..', '..', "spec_helper")}"
include MicrotingUtils::Comparison::Comparison

describe MicrotingUtils::Comparison::Comparison do
  it "should compare_xml_with_empty_spaces" do
    a = %Q{<a>   </a>}
    b = %Q{
  <a>
  
  </a>}
    a_rexml = REXML::Document.new a
    b_rexml = REXML::Document.new b
    #this should not fail due some line break
    compare_xml_elements(a_rexml, b_rexml)
  end
  it "should compare xml with empty spaces 2" do
    a = %Q{  <a>   </a>  }
    b = %Q{
  <a>
  </a>}
    a_rexml = REXML::Document.new a
    b_rexml = REXML::Document.new b
    #this should not fail due some line break
    compare_xml_elements(a_rexml, b_rexml)  
  end
  it "should compare xml with wrong value" do
    a = %Q{<a>   .</a>}
    b = %Q{
  <a>
  </a>}
    a_rexml = REXML::Document.new a
    b_rexml = REXML::Document.new b
    #this should not fail due some line break
    lambda { compare_xml_elements(a_rexml, b_rexml) }.should raise_error
#    assert_raise {  }
  end
  it "should compare xml with wrong value2" do
    a = %Q{
  <a>
  .</a>}
    b = %Q{
  <a>
  </a>}
    a_rexml = REXML::Document.new a
    b_rexml = REXML::Document.new b
    #this should not fail due some line break
    lambda { compare_xml_elements(a_rexml, b_rexml) }.should raise_error
#    assert_raise { compare_xml_elements(a_rexml, b_rexml) }
  end
end




