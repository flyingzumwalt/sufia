class GenericFilesController < ApplicationController
  
  include Hydra::Controller
  include Hydra::AssetsControllerHelper  # This is to get apply_depositor_metadata method
  include Hydra::FileAssetsHelper

  # actions: audit, index, create, new, edit, show, update, destroy
  before_filter :authenticate_user!, :only=>[:create, :new]
  before_filter :enforce_access_controls, :only=>[:edit, :update, :show, :audit, :index, :destroy]
  prepend_before_filter :normalize_identifier, :only=>[:audit, :edit, :show, :update, :destroy] 

  # routed to /files/new
  def new
    @generic_file = GenericFile.new 
    @batch = Batch.new
    @batch.save
    @dc_metadata = [
      ['Based Near', 'based_near'],
      ['Contributor', 'contributor'],
      ['Creator', 'creator'], 
      ['Date Created', 'date_created'], 
      ['Description', 'description'],
      ['Identifier', 'identifier'],
      ['Language', 'language'], 
      ['Publisher', 'publisher'], 
      ['Rights', 'rights'],
      ['Subject', 'subject'], 
      ['Tag', 'tag'], 
      ['Title', 'title'], 
    ]
  end

  # routed to /files/:id/edit
  def edit
    @generic_file = GenericFile.find(params[:id])
  end


  def index
    @generic_files = GenericFile.all
    render :json => @generic_files.collect { |p| p.to_jq_upload }.to_json
  end


  # routed to /files (POST)
  def create
    create_and_save_generic_file 
    if @generic_file
      respond_to do |format|
        format.html {
          render :json => [@generic_file.to_jq_upload].to_json,
            :content_type => 'text/html',
            :layout => false
        }
        format.json {
          render :json => [@generic_file.to_jq_upload].to_json
        }
      end
    else
      puts "respond bad"
      render :json => [{:error => "custom_failure"}], :status => 304
    end
#    create_and_save_generic_files_from_params
#
#    if @generic_files.empty? 
#      flash[:notice] = "You must specify a file to upload" 
#      redirect_params = {:controller => "generic_files", :action => "new"} 
#    elsif params[:generic_file].has_key? :creator and params[:generic_file][:creator].empty?
#      flash[:notice] = "You must include a creator."
#      redirect_params = {:controller => "generic_files", :action => "new"} 
#    else
#      notice = []
#      @generic_files.each do |gf|
#        notice << render_to_string(:partial=>'generic_files/asset_saved_flash', :locals => { :generic_file => gf })
#      end
#      flash[:notice] = notice.join("<br/>".html_safe) unless notice.blank?
#      redirect_params = {:controller => "dashboard", :action => "index"} 
#    end
#    redirect_to redirect_params 
  end

  # routed to /files/:id
  def show
    @generic_file = GenericFile.find(params[:id])
  end

  # routed to /files/:id/audit (POST)
  def audit
    @generic_file = GenericFile.find(params[:id])
    render :json=>@generic_file.content.audit
  end
 
  # routed to /files/:id (PUT)
  def update
    @generic_file = GenericFile.find(params[:id])
    @generic_file.update_attributes(params[:generic_file].reject { |k,v| k=="Filedata" || k=="Filename"})
    @generic_file.date_modified = [Time.now.ctime]

    #added to cause solr to re-index facets
    @generic_file.update_index
    
    flash[:notice] = "Successfully updated." 
    add_posted_blob_to_asset(generic_file, params[:Filedata]) if params.has_key?(:Filedata) 
    render :edit 
  end


  protected
  def normalize_identifier
    params[:id] = "#{ScholarSphere::Application.config.id_namespace}:#{params[:id]}" unless params[:id].start_with? ScholarSphere::Application.config.id_namespace
  end

  def create_and_save_generic_file
      
    if params.has_key?(:files)
      @generic_file = GenericFile.new
      file = params[:files][0]
      add_posted_blob_to_asset(@generic_file,file)
      apply_depositor_metadata(@generic_file)
      # Delete this next line when GenericFile.label no longer wipes out the title
      @generic_file.label = file.original_filename
      @generic_file.save
      if params.has_key?(:batch_id)
        @batch = Batch.find(params[:batch_id])
        @batch.part << @generic_file.pid
        @batch.save
      else
        puts "unable to find batch to attach to"
      end
      @generic_file
    else
      @generic_file
    end
  end


  # takes form file inputs and assigns meta data individually 
  # to each generic file asset and saves generic file assets # @param [Hash] of form fields
  def create_and_save_generic_files_from_params
    @generic_files = []
    if params.has_key?(:Filedata)
      params[:Filedata].each do |file|
        params[:generic_file] = {} unless params.has_key? :generic_file
        generic_file = GenericFile.new(params[:generic_file].reject {|k,v| k=="Filedata" || k=="Filename"})
        
        add_posted_blob_to_asset(generic_file,file)
        apply_depositor_metadata(generic_file)
        if params.has_key?(:permission)
          generic_file.datastreams["rightsMetadata"].permissions({:group=>"public"}, params[:permission][:group][:public])
        else
          generic_file.datastreams["rightsMetadata"].permissions({:group=>"public"}, "none")
        end
        generic_file.label = file.original_filename
        # Delete this next line when GenericFile.label no longer wipes out the title

        generic_file.based_near = params[:generic_file][:based_near] if params[:generic_file].has_key?(:based_near) 
        generic_file.contributor = params[:generic_file][:contributor] if params[:generic_file].has_key?(:contributor)
        generic_file.creator = params[:generic_file][:creator] if params[:generic_file].has_key?(:creator)
        generic_file.date_created = params[:generic_file][:date_created] if params[:generic_file].has_key?(:date_created)
        generic_file.description = params[:generic_file][:description] if params[:generic_file].has_key?(:description)
        generic_file.identifier = params[:generic_file][:identifier] if params[:generic_file].has_key?(:identifier)
        generic_file.language = params[:generic_file][:language] if params[:generic_file].has_key?(:language)
        generic_file.publisher = params[:generic_file][:publisher] if params[:generic_file].has_key?(:publisher)
        generic_file.rights = params[:generic_file][:rights] if params[:generic_file].has_key?(:rights)
        generic_file.subject = params[:generic_file][:subject] if params[:generic_file].has_key?(:subject)
        generic_file.tag = params[:generic_file][:tag] if params[:generic_file].has_key?(:tag)
        generic_file.title = params[:generic_file][:title] if params[:generic_file].has_key?(:title) 

        generic_file.date_uploaded  << Time.now.ctime
        generic_file.date_modified  << Time.now.ctime

        generic_file.save
        #generic_file.delay.save
        @generic_files << generic_file
      end
    end
    @generic_files
  end

end
