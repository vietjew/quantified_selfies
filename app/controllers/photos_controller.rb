require 'imagga'
class PhotosController < ApplicationController

  def index
    @photos = Photo.order("created_at desc").to_a
  end

  def new
    @photo = Photo.new(:title => "My photo \##{1 + (Photo.maximum(:id) || 0)}")
    if unsigned_mode?
      @unsigned = true
      # make sure we have the appropriate preset
      @preset_name = "sample_" + Digest::SHA1.hexdigest(Cloudinary.config.api_key + Cloudinary.config.api_secret)
      # @preset_name = "sample_" + Digest::SHA1.hexdigest(ENV['cloudinary_api_key'] + ENV['cloudinary_api_secret'])
      begin
        preset = Cloudinary::Api.upload_preset(@preset_name)
        if !preset["settings"]["return_delete_token"]
          Cloudinary::Api.update_upload_preset(@preset_name, :return_delete_token=>true)
        end
      rescue
        # An upload preset may contain (almost) all parameters that are used in upload. The following is just for illustration purposes
        Cloudinary::Api.create_upload_preset(:name => @preset_name, :unsigned => true, :folder => "preset_folder", :return_delete_token=>true)
      end
    end
    render view_for_new
  end

  def create
    @photo = Photo.new(photo_params)
    # In through-the-server mode, the image is first uploaded to the Rails server.
    # When @photo is saved, Carrierwave uploads the image to Cloudinary.
    # The upload metadata (e.g. image size) is then available in the
    # uploader object of the model (@photo.image).
    # In direct mode, the image is uploaded to Cloudinary by the browser,
    # and upload metadata is available in JavaScript (see new_direct.html.erb).
    if !@photo.save
      @error = @photo.errors.full_messages.join('. ')
      render view_for_new
      return
    end
    if !direct_upload_mode?
      # In this sample, we want to store a part of the upload metadata
      # ("bytes" - the image size) in the Photo model.
      # In direct mode, we pass the image size via a hidden form field
      # filled by JavaScript (see new_direct.html.erb).
      # In through-the-server mode, we need to copy this field from Cloudinary
      # upload metadata. The metadata is only available after Carrierwave
      # performs the upload (in @photo.save), so we need to update the
      # already saved photo here.
      @photo.update_attributes(:bytes => @photo.image.metadata['bytes'])
      # Show upload metadata in the view
      @upload = @photo.image.metadata
    end
    imagga = Imagga.new({image_url: @photo.image.url})
    imagga.tag
    @photo.tags = imagga.tags
    @photo.save
    redirect_to @photo
  end

  def show
    @photo = Photo.find(params[:id])
  end

  protected

  def direct_upload_mode?
    params[:direct].present?
  end

  def unsigned_mode?
    params[:unsigned].present?
  end

  def view_for_new
    direct_upload_mode? ? "new_direct" : "new"
  end

  private

  def photo_params
    params.require(:photo).permit(:title, :image, :image_cache, :bytes)
  end

end
